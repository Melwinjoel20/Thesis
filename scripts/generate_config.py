#!/usr/bin/env python3
"""
Writes infra/config.json from Terraform outputs — replaces every stale
hand-edited value (Cognito IDs, client secret, bucket, SNS ARN, EB names)
with the live ones from the deployed stacks.

Run AFTER the terraform stacks are applied:
    python3 scripts/generate_config.py

Requires: terraform on PATH, and the stacks initialized in terraform/usecase/*.
CI runs this right before building the EB bundle.
"""

import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = REPO_ROOT / "infra" / "config.json"
TF_DIR = REPO_ROOT / "terraform" / "usecase"


def tf_outputs(stack: str) -> dict:
    """Return {name: value} outputs for one stack, {} if the stack has none."""
    try:
        raw = subprocess.check_output(
            ["terraform", f"-chdir={TF_DIR / stack}", "output", "-json"],
            stderr=subprocess.PIPE,
        )
        return {k: v["value"] for k, v in json.loads(raw).items()}
    except subprocess.CalledProcessError as exc:
        print(f"WARN: could not read outputs for '{stack}': {exc.stderr.decode().strip()}")
        return {}


def main() -> int:
    app = tf_outputs("app")
    storage = tf_outputs("storage")
    frontend = tf_outputs("frontend")

    missing = [
        name
        for name, outs, key in [
            ("app.cognito_user_pool_id", app, "cognito_user_pool_id"),
            ("storage.bucket_name", storage, "bucket_name"),
        ]
        if key not in outs
    ]
    if missing:
        print(f"ERROR: required outputs missing: {missing} — are the stacks applied?")
        return 1

    config = json.loads(CONFIG_PATH.read_text())

    region = config.get("region", "us-east-1")
    bucket = storage["bucket_name"]

    config.update(
        {
            "user_pool_id": app["cognito_user_pool_id"],
            "app_client_id": app["cognito_app_client_id"],
            "app_client_secret": app["cognito_app_client_secret"],
            "domain_url": app.get("cognito_domain_url", ""),
            "bucket_name": bucket,
            "s3_logo_url": f"https://{bucket}.s3.{region}.amazonaws.com/images/EasyCartLogo.png",
            "sns_topic_arn": app.get("sns_topic_arn", ""),
        }
    )

    # Server-side cart: templates call these local Django endpoints, and
    # Django invokes the private Lambdas via boto3 (store/cart_api.py).
    config["lambda_cart_endpoints"] = {
        "add_to_cart": "/store/api/cart/add/",
        "view_cart": "/store/api/cart/view/",
        "remove_cart_item": "/store/api/cart/remove/",
        "place_order": "/store/api/order/place/",
        "tax_calculator": "/store/api/tax/",
    }
    # Function names the proxy views invoke (map key -> deployed name).
    config["lambda_functions"] = app.get("lambda_function_names", {})

    if frontend:
        config["eb_application_name"] = frontend.get("eb_application_name", config.get("eb_application_name"))
        config["eb_environment_name"] = frontend.get("eb_environment_name", config.get("eb_environment_name"))

    CONFIG_PATH.write_text(json.dumps(config, indent=4) + "\n")
    print(f"wrote {CONFIG_PATH}")
    for k in ("user_pool_id", "app_client_id", "bucket_name", "sns_topic_arn",
              "eb_application_name", "eb_environment_name"):
        print(f"  {k} = {config.get(k)}")
    print("  app_client_secret = ***")
    return 0


if __name__ == "__main__":
    sys.exit(main())
