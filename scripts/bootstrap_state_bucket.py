#!/usr/bin/env python3
"""
Create the Terraform remote-state bucket if it does not already exist.

Terraform stores its state in an S3 bucket, so the bucket has to exist before
any stack can init. This handles that one-time bootstrap: it derives a bucket
name from the current AWS account, creates it with versioning enabled if it is
missing, and writes the name into terraform/backend.hcl so every stack picks it
up. Safe to run on every deploy - if the bucket already exists it does nothing.

Usage:
    python3 scripts/bootstrap_state_bucket.py
    python3 scripts/bootstrap_state_bucket.py --name my-custom-bucket
    python3 scripts/bootstrap_state_bucket.py --region eu-west-1
"""

import argparse
import re
import sys
from pathlib import Path

import boto3
from botocore.exceptions import ClientError

REPO_ROOT = Path(__file__).resolve().parent.parent
BACKEND_HCL = REPO_ROOT / "terraform" / "backend.hcl"


def account_id(region):
    return boto3.client("sts", region_name=region).get_caller_identity()["Account"]


def bucket_exists(s3, name):
    try:
        s3.head_bucket(Bucket=name)
        return True
    except ClientError as e:
        if e.response["Error"]["Code"] in ("404", "NoSuchBucket"):
            return False
        # 403 means it exists but is owned by someone else, or we lack access
        raise


def create_bucket(s3, name, region):
    if region == "us-east-1":
        s3.create_bucket(Bucket=name)
    else:
        s3.create_bucket(
            Bucket=name,
            CreateBucketConfiguration={"LocationConstraint": region},
        )
    s3.put_bucket_versioning(
        Bucket=name,
        VersioningConfiguration={"Status": "Enabled"},
    )


def update_backend_hcl(name):
    if not BACKEND_HCL.exists():
        print(f"warning: {BACKEND_HCL} not found, skipping update")
        return
    text = BACKEND_HCL.read_text()
    new = re.sub(r'bucket\s*=\s*"[^"]*"', f'bucket       = "{name}"', text, count=1)
    if new != text:
        BACKEND_HCL.write_text(new)
        print(f"updated backend.hcl bucket -> {name}")
    else:
        print("backend.hcl already points at this bucket")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--region", default="us-east-1")
    ap.add_argument("--name", help="override the derived bucket name")
    args = ap.parse_args()

    s3 = boto3.client("s3", region_name=args.region)

    # Derive a stable, account-scoped name so a new lab account gets its own
    # bucket automatically. Bucket names are globally unique, so the account id
    # keeps it collision-free.
    name = args.name or f"easycart-tfstate-{account_id(args.region)}"

    try:
        if bucket_exists(s3, name):
            print(f"state bucket already exists: {name}")
        else:
            create_bucket(s3, name, args.region)
            print(f"created state bucket: {name} (versioning enabled)")
    except ClientError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    update_backend_hcl(name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
