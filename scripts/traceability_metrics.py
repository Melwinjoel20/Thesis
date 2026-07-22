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


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--hours", type=int, default=24, help="analysis window")
    ap.add_argument("--region", default="us-east-1")
    ap.add_argument("--client-cidr", default="172.16.0.0/22", help="VPN client CIDR")
    ap.add_argument("--json", help="write results to this file")
    args = ap.parse_args()

    end = int(datetime.now(timezone.utc).timestamp())
    start = int((datetime.now(timezone.utc) - timedelta(hours=args.hours)).timestamp())

    flow_groups = tf_output(TF_NET, "flow_log_group_names") or {}
    vpn_group = tf_output(TF_NET, "vpn_log_group_name")
    api_group = tf_output(TF_NET, "api_access_log_group_name")
    if not flow_groups:
        print("No flow log groups found - is the networking stack applied?")
        return 1

    print(f"Window: {args.hours}h  ({datetime.fromtimestamp(start, timezone.utc):%Y-%m-%d %H:%M} UTC onwards)\n")

    # ---------------- network layer ----------------
    print("[1/3] Collecting source addresses from VPC Flow Logs")
    observed: dict[str, set[str]] = defaultdict(set)
    for role, group in flow_groups.items():
        rows = cw_query(
            group,
            "fields @message | parse @message '* * * * * * * * * * * * * * * * * * * *' "
            "as version, vpcId, subnetId, eni, account, srcaddr, dstaddr, srcport, dstport, "
            "protocol, packets, bytes, startT, endT, action, status, direction, pktSrc, pktDst, path "
            "| filter action = 'ACCEPT' | stats count() by srcaddr, pktSrc",
            start, end, args.region,
        )
        for r in rows:
            for key in ("srcaddr", "pktSrc"):
                a = r.get(key, "")
                if a and a not in ("-", "") and not is_infrastructure(a):
                    observed[role].add(a)
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
