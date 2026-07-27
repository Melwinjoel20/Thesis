import boto3
import json
import os
import datetime
from botocore.exceptions import ClientError
from passlib.hash import pbkdf2_sha256

CONFIG_PATH = "infra/config.json"
ADMIN_TABLE_KEY = "admin_users_table"
DEFAULT_ADMIN_TABLE_NAME = "EasyCartAdminUsers"


def load_config():
    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH) as f:
            return json.load(f)
    return {}


def save_config(data):
    os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
    with open(CONFIG_PATH, "w") as f:
        json.dump(data, f, indent=4)
    print(" config.json updated")


def table_exists(dynamodb, table_name):
    try:
        dynamodb.describe_table(TableName=table_name)
        return True
    except ClientError:
        return False


def create_admin_table_if_needed(region, table_name):
    dynamodb = boto3.client("dynamodb", region_name=region)

    if table_exists(dynamodb, table_name):
        print(f" Table already exists: {table_name}")
        return

    print(f"\n Creating table: {table_name} ...")

    dynamodb.create_table(
        TableName=table_name,
        AttributeDefinitions=[
            {"AttributeName": "email", "AttributeType": "S"},
        ],
        KeySchema=[
            {"AttributeName": "email", "KeyType": "HASH"},
        ],
        BillingMode="PAY_PER_REQUEST",
    )

    print("⏳ Waiting for table to be ACTIVE...")
    waiter = dynamodb.get_waiter("table_exists")
    waiter.wait(TableName=table_name)

    print(f" Created table: {table_name}")


def create_admin_user(region, table_name, email, password, role="SUPER_ADMIN"):
    """
    Creates an admin user in DynamoDB with a hashed password.
    """
    db = boto3.resource("dynamodb", region_name=region)
    table = db.Table(table_name)

    password_hash = pbkdf2_sha256.hash(password)

    item = {
        "user_id": email,  # table hash key; email doubles as the identifier
        "email": email,
        "password_hash": password_hash,
        "role": role,  # "ADMIN" or "SUPER_ADMIN"
        "is_active": True,
        "created_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    }

    table.put_item(Item=item)
    print(f" Added admin user: {email} ({role})")


def main():
    print(" EasyCart DynamoDB Setup — Admin Users")

    config = load_config()
    region = config.get("region", "us-east-1")

    # Choose table name (can override in config if needed)
    table_name = config.get(ADMIN_TABLE_KEY, DEFAULT_ADMIN_TABLE_NAME)

    # 1) Create table if needed
    create_admin_table_if_needed(region, table_name)

    # Save table name back to config for future reference
    config[ADMIN_TABLE_KEY] = table_name
    save_config(config)

    # 2) Seed one admin user. Non-interactive when ADMIN_EMAIL / ADMIN_PASSWORD
    # are set in the environment (so this runs unattended in CI); falls back to
    # prompts for local use. If neither is provided and stdin is not a TTY
    # (e.g. a pipeline), skip user creation cleanly rather than erroring.
    import sys
    print("\n[2] Create initial admin user")

    env_email = os.environ.get("ADMIN_EMAIL", "").strip()
    env_password = os.environ.get("ADMIN_PASSWORD", "").strip()
    env_role = os.environ.get("ADMIN_ROLE", "SUPER_ADMIN").strip().upper()

    if env_email and env_password:
        email, password, role = env_email, env_password, env_role
        print(f"  Using ADMIN_EMAIL from environment: {email}")
    elif not sys.stdin.isatty():
        print("  No ADMIN_EMAIL/ADMIN_PASSWORD set and no interactive terminal;")
        print("  skipping admin user creation. Set those env vars to seed one in CI.")
        print("\n Admin users table ready (no initial user created).")
        return
    else:
        email = input("Admin email: ").strip()
        if not email:
            print(" Email is required. Exiting.")
            return
        password = input("Admin password: ").strip()
        if not password:
            print(" Password is required. Exiting.")
            return
        role = input("Role (ADMIN/SUPER_ADMIN) [SUPER_ADMIN]: ").strip().upper() or "SUPER_ADMIN"

    if role not in ("ADMIN", "SUPER_ADMIN"):
        print("Invalid role, defaulting to ADMIN")
        role = "ADMIN"

    create_admin_user(region, table_name, email, password, role)

    print("\n Admin users table ready and initial user created!")


if __name__ == "__main__":
    main()
