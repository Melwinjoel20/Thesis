#!/usr/bin/env python3
"""
Fetch a Cognito ID token for testing the internal JWT API.

Usage:
    python3 scripts/get_token.py <email> <password>

Reads pool/client/secret from infra/config.json (run generate_config.py
first). Prints the ID token — pass it to the API in the Authorization
header (raw token, no 'Bearer' prefix, as the Cognito authorizer expects):

    TOKEN=$(python3 scripts/get_token.py you@example.com 'YourPassword')
    curl -H "Authorization: $TOKEN" "<internal_api_base_url>/view-cart?user_id=you@example.com"
"""

import base64
import hashlib
import hmac
import json
import sys
from pathlib import Path

import boto3

CONFIG = json.loads((Path(__file__).resolve().parent.parent / "infra" / "config.json").read_text())


def secret_hash(username: str) -> str:
    digest = hmac.new(
        CONFIG["app_client_secret"].encode(),
        (username + CONFIG["app_client_id"]).encode(),
        hashlib.sha256,
    ).digest()
    return base64.b64encode(digest).decode()


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 1
    username, password = sys.argv[1], sys.argv[2]

    client = boto3.client("cognito-idp", region_name=CONFIG["region"])
    resp = client.initiate_auth(
        ClientId=CONFIG["app_client_id"],
        AuthFlow="USER_PASSWORD_AUTH",
        AuthParameters={
            "USERNAME": username,
            "PASSWORD": password,
            "SECRET_HASH": secret_hash(username),
        },
    )
    print(resp["AuthenticationResult"]["IdToken"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
