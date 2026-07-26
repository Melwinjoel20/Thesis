#!/usr/bin/env python3
"""
Zero-trust traceability analyser.

Computes two forensic-readiness metrics from the CloudWatch log substrate
created by the Observability module:

  Tu (network-layer IP User Traceability), after Inukonda et al. (2023):

        Tu = (Iu / IT) x 100

      IT = distinct private source addresses observed in VPC Flow Logs
      Iu = those addresses that can be resolved to an authenticated identity
           by joining against Client VPN connection (translation) logs

  Ts (service-layer traceability), this work's extension:

        Ts = (Ra / RT) x 100

      RT = requests recorded in the private API Gateway access log
      Ra = those carrying a verified authoriser identity (a token subject)

The network metric answers "can we attribute a packet to a person?"; the
service metric answers "can we attribute a call to a verified principal?".
Reporting both is the point: a deployment can score highly on one and poorly
on the other, and only the pair describes forensic readiness end to end.

Usage:
    python3 scripts/traceability_metrics.py --hours 24
    python3 scripts/traceability_metrics.py --hours 6 --json results.json
"""

from __future__ import annotations

import argparse
import ipaddress
import json
import subprocess
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TF_NET = REPO_ROOT / "terraform" / "usecase" / "networking"

# Addresses that are infrastructure rather than subjects: the VPC resolver,
# endpoint ENIs and health checkers. Counting these as "untraceable users"
# would understate Tu for reasons that have nothing to do with identity.
INFRASTRUCTURE_SUFFIXES = {".2"}


def tf_output(stack_dir: Path, name: str):
    try:
        raw = subprocess.check_output(
            ["terraform", f"-chdir={stack_dir}", "output", "-json", name],
            stderr=subprocess.PIPE,
        )
        return json.loads(raw)
    except subprocess.CalledProcessError as exc:
        print(f"ERROR reading terraform output '{name}': {exc.stderr.decode().strip()}")
        return None


def cw_query(group: str, query: str, start: int, end: int, region: str = "us-east-1"):
    """Run a CloudWatch Logs Insights query and block until it completes."""
    try:
        qid = subprocess.check_output([
            "aws", "logs", "start-query", "--region", region,
            "--log-group-name", group,
            "--start-time", str(start), "--end-time", str(end),
            "--query-string", query, "--limit", "10000",
            "--query", "queryId", "--output", "text",
        ], stderr=subprocess.PIPE).decode().strip()
    except subprocess.CalledProcessError as exc:
        print(f"  ! query failed on {group}: {exc.stderr.decode().strip()}")
        return []

    import time
    for _ in range(60):
        time.sleep(2)
        out = json.loads(subprocess.check_output([
            "aws", "logs", "get-query-results", "--region", region,
            "--query-id", qid, "--output", "json",
        ]))
        if out.get("status") == "Complete":
            return [{f["field"]: f["value"] for f in row} for row in out.get("results", [])]
    print(f"  ! query timed out on {group}")
    return []


def is_infrastructure(addr: str) -> bool:
    return any(addr.endswith(s) for s in INFRASTRUCTURE_SUFFIXES)


def in_client_cidr(addr: str, cidr: str) -> bool:
    try:
        return ipaddress.ip_address(addr) in ipaddress.ip_network(cidr)
    except ValueError:
        return False



def read_flow_logs_s3(bucket: str, prefix: str, start: int, end: int, region: str):
    """Stream ACCEPT source/pkt-source addresses from S3-delivered flow logs.

    Flow logs land as gzipped text objects under <prefix>/AWSLogs/.../. Each
    line follows the explicit field order declared in the Observability module:
    ... srcaddr(6) dstaddr(7) ... action(15) ... pkt-srcaddr(18) ...
    Field positions are 0-based after splitting on whitespace; the leading
    fields are version(0) vpc-id(1) subnet-id(2) interface-id(3) account(4)
    srcaddr(5) dstaddr(6) srcport(7) dstport(8) protocol(9) packets(10)
    bytes(11) start(12) end(13) action(14) log-status(15) flow-direction(16)
    pkt-srcaddr(17) pkt-dstaddr(18) traffic-path(19).
    """
    import gzip
    addrs = []
    token = None
    keys = []
    while True:
        cmd = ["aws", "s3api", "list-objects-v2", "--region", region,
               "--bucket", bucket, "--prefix", f"{prefix}/",
               "--query", "Contents[].Key", "--output", "json"]
        if token:
            cmd += ["--starting-token", token]
        try:
            out = subprocess.check_output(cmd, stderr=subprocess.PIPE).decode()
            page = json.loads(out) or []
        except subprocess.CalledProcessError as exc:
            print(f"  ! list failed for {prefix}: {exc.stderr.decode().strip()}")
            return addrs
        keys.extend(page)
        break  # single page is plenty at lab scale

    for key in keys:
        try:
            raw = subprocess.check_output(
                ["aws", "s3", "cp", f"s3://{bucket}/{key}", "-", "--region", region],
                stderr=subprocess.DEVNULL)
            text = gzip.decompress(raw).decode(errors="ignore")
        except Exception:
            continue
        for line in text.splitlines():
            f = line.split()
            if len(f) < 18 or f[0] == "version":
                continue
            if f[14] != "ACCEPT":
                continue
            addrs.append(f[5])   # srcaddr
            addrs.append(f[17])  # pkt-srcaddr (pre-NAT/ALB rewrite)
    return addrs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--hours", type=int, default=24, help="analysis window")
    ap.add_argument("--region", default="us-east-1")
    ap.add_argument("--client-cidr", default="172.16.0.0/22", help="VPN client CIDR")
    ap.add_argument("--json", help="write results to this file")
    args = ap.parse_args()

    end = int(datetime.now(timezone.utc).timestamp())
    start = int((datetime.now(timezone.utc) - timedelta(hours=args.hours)).timestamp())

    flow_bucket = tf_output(TF_NET, "flow_log_bucket")
    vpn_group = tf_output(TF_NET, "vpn_log_group_name")
    api_group = tf_output(TF_NET, "api_access_log_group_name")
    if not flow_bucket:
        print("No flow log bucket found - is the networking stack applied?")
        return 1

    print(f"Window: {args.hours}h  ({datetime.fromtimestamp(start, timezone.utc):%Y-%m-%d %H:%M} UTC onwards)\n")

    # ---------------- network layer (S3-delivered flow logs) ----------------
    print("[1/3] Collecting source addresses from VPC Flow Logs (S3)")
    observed: dict[str, set[str]] = defaultdict(set)
    roles = ["hub", "frontend", "app", "database"]
    for role in roles:
        for addr in read_flow_logs_s3(flow_bucket, role, start, end, args.region):
            if addr and addr not in ("-", "") and not is_infrastructure(addr):
                observed[role].add(addr)
        print(f"      {role:9s} {len(observed[role]):4d} distinct source addresses")

    all_sources = set().union(*observed.values()) if observed else set()

    # ---------------- VPN translation layer ----------------
    print("\n[2/3] Resolving addresses to identities via VPN connection logs")
    identity_map: dict[str, str] = {}
    if vpn_group:
        rows = cw_query(
            vpn_group,
            "fields @message | filter @message like /connection-log/ or @message like /username/ "
            "| parse @message '\"username\":\"*\"' as username "
            "| parse @message '\"client-ip\":\"*\"' as clientIp "
            "| filter ispresent(clientIp) | stats count() by clientIp, username",
            start, end, args.region,
        )
        for r in rows:
            ip, user = r.get("clientIp"), r.get("username")
            if ip and user:
                identity_map[ip] = user
        print(f"      {len(identity_map)} VPN-assigned addresses mapped to certificate identities")
    else:
        print("      ! no VPN log group - Tu will reflect network records only")

    vpn_sourced = {a for a in all_sources if in_client_cidr(a, args.client_cidr)}
    attributable = {a for a in all_sources if a in identity_map}

    IT = len(all_sources)
    Iu = len(attributable)
    Tu = (Iu / IT * 100) if IT else 0.0

    # ---------------- service layer ----------------
    print("\n[3/3] Measuring service-layer attribution from API access logs")
    RT = Ra = 0
    principals: set[str] = set()
    if api_group:
        rows = cw_query(
            api_group,
            "fields @message | stats count() as n by "
            "coalesce(subject, 'ANONYMOUS') as principal",
            start, end, args.region,
        )
        for r in rows:
            n = int(r.get("n", 0))
            RT += n
            if r.get("principal") and r["principal"] != "ANONYMOUS":
                Ra += n
                principals.add(r["principal"])
        print(f"      {RT} requests, {Ra} carrying a verified token subject, "
              f"{len(principals)} distinct principals")
    else:
        print("      ! no API access log group found")

    Ts = (Ra / RT * 100) if RT else 0.0

    # ---------------- report ----------------
    print("\n" + "=" * 62)
    print("FORENSIC READINESS")
    print("=" * 62)
    print(f"  Network layer   IT = {IT:5d} distinct source addresses observed")
    print(f"                  Iu = {Iu:5d} resolved to an authenticated identity")
    print(f"                  Tu = {Tu:6.2f} %   (IP User Traceability)")
    print(f"                       {len(vpn_sourced)} addresses originated in the VPN client CIDR")
    print(f"  Service layer   RT = {RT:5d} private-API requests")
    print(f"                  Ra = {Ra:5d} with a verified principal")
    print(f"                  Ts = {Ts:6.2f} %   (service-layer traceability)")
    print("=" * 62)

    unattributed = sorted(all_sources - attributable)[:15]
    if unattributed:
        print("\nUnattributed sources (first 15) - expected to be service ENIs and")
        print("endpoint interfaces rather than subjects; inspect before drawing")
        print("conclusions about coverage:")
        for a in unattributed:
            print(f"  {a}")

    if args.json:
        Path(args.json).write_text(json.dumps({
            "window_hours": args.hours,
            "generated": datetime.now(timezone.utc).isoformat(),
            "network": {"IT": IT, "Iu": Iu, "Tu": round(Tu, 2),
                        "vpn_sourced": len(vpn_sourced),
                        "per_vpc": {k: len(v) for k, v in observed.items()}},
            "service": {"RT": RT, "Ra": Ra, "Ts": round(Ts, 2),
                        "distinct_principals": len(principals)},
            "unattributed_sample": unattributed,
        }, indent=2) + "\n")
        print(f"\nwrote {args.json}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
