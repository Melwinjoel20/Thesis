import boto3
import os
import json
import uuid
from botocore.exceptions import ClientError

CONFIG_PATH = "infra/config.json"


def load_config():
    with open(CONFIG_PATH) as f:
        return json.load(f)


# Build filename → S3-key mapping from the local folder.
# Terraform (storage stack) already uploaded the files with this key pattern.
# No S3 calls needed here.
def build_image_mapping(folder):
    mapping = {}
    for file_name in os.listdir(folder):
        if file_name.lower().endswith((".png", ".jpg", ".jpeg")):
            mapping[file_name] = f"product-images/{file_name}"
            print(f"Mapped {file_name} -> product-images/{file_name}")
    return mapping


def table_exists(client, table_name):
    try:
        client.describe_table(TableName=table_name)
        return True
    except ClientError:
        return False


def create_table(region, table_name):
    client = boto3.client("dynamodb", region_name=region)
    if table_exists(client, table_name):
        print(f"Table exists: {table_name}")
        return
    print(f"Creating table -> {table_name}")
    client.create_table(
        TableName=table_name,
        AttributeDefinitions=[{"AttributeName": "product_id", "AttributeType": "S"}],
        KeySchema=[{"AttributeName": "product_id", "KeyType": "HASH"}],
        BillingMode="PAY_PER_REQUEST"
    )
    client.get_waiter("table_exists").wait(TableName=table_name)
    print(f"Created DynamoDB table -> {table_name}")


def _stable_pid(table_name, name):
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"{table_name}:{name}"))


def seed_table(region, table_name, products):
    dynamodb = boto3.resource("dynamodb", region_name=region)
    table = dynamodb.Table(table_name)
    existing = table.scan(Select="COUNT").get("Count", 0)
    if existing > 0:
        print(f"Skipping {table_name}: already has {existing} item(s)")
        return
    print(f"Seeding table -> {table_name}")
    for p in products:
        pid = _stable_pid(table_name, p["name"])
        table.put_item(Item={
            "product_id": pid,
            "name":        p["name"],
            "description": p["description"],
            "price":       p["price"],
            "image":       p.get("image", "")
        })
        print(f"Added: {p['name']} -> {pid}")


def update_images(region, table_name, mapping):
    dynamodb = boto3.resource("dynamodb", region_name=region)
    table = dynamodb.Table(table_name)
    items = table.scan().get("Items", [])
    for item in items:
        name_key = item["name"].replace(" ", "").replace("_", "").lower()
        for file_name, key in mapping.items():
            if name_key in file_name.replace(" ", "").replace("_", "").lower():
                table.update_item(
                    Key={"product_id": item["product_id"]},
                    UpdateExpression="SET image = :u",
                    ExpressionAttributeValues={":u": key}
                )
                print(f"Updated image key -> {item['name']}")
                break


def main():
    config = load_config()
    region         = config["region"]
    tables         = config["dynamodb_tables"]
    images_folder  = config["product_images_folder"]

    print("\nStarting EasyCart PRODUCT SETUP\n")

    # Build the filename→S3-key mapping without uploading anything.
    # Terraform already uploaded the files in the storage stack.
    image_mapping = build_image_mapping(images_folder)

    SAMPLE_DATA = {
        "MenClothes": [
            {"name": "Classic Green Sweater",      "description": "Warm knit sweater in forest green", "price": 69},
            {"name": "Classic White Shirt",         "description": "Crisp cotton formal shirt",         "price": 59},
            {"name": "Essential Polo Tshirt Set",   "description": "Two-pack everyday polo tees",       "price": 49}
        ],
        "WomenClothes": [
            {"name": "Leopard Mesh Top",    "description": "Sheer mesh top, leopard print",      "price": 49},
            {"name": "Striped Sweatshirt",  "description": "Relaxed-fit striped sweatshirt",     "price": 39},
            {"name": "White Ribbed Top",    "description": "Fitted ribbed knit top",             "price": 29}
        ],
        "KidsClothes": [
            {"name": "Christmas Sweater",              "description": "Festive holiday knit",          "price": 25},
            {"name": "Construction Print Sweatshirt",  "description": "Diggers and trucks print",      "price": 19},
            {"name": "Red Reindeer Sweatshirt",        "description": "Red sweatshirt with reindeer",  "price": 22}
        ]
    }

    for table_name in tables:
        create_table(region, table_name)
        seed_table(region, table_name, SAMPLE_DATA[table_name])
        update_images(region, table_name, image_mapping)

    print("\nALL DONE — DynamoDB seeded, image keys written.\n")


if __name__ == "__main__":
    main()