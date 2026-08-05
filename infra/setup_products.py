import boto3
import os
import json
import uuid
from botocore.exceptions import ClientError

CONFIG_PATH = "infra/config.json"

def load_config():
    with open(CONFIG_PATH) as f:
        return json.load(f)

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
    client.create_table(
        TableName=table_name,
        AttributeDefinitions=[{"AttributeName": "product_id", "AttributeType": "S"}],
        KeySchema=[{"AttributeName": "product_id", "KeyType": "HASH"}],
        BillingMode="PAY_PER_REQUEST"
    )
    client.get_waiter("table_exists").wait(TableName=table_name)
    print(f"Created: {table_name}")

def _stable_pid(table_name, name):
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"{table_name}:{name}"))

def seed_or_update_table(region, table_name, products):
    """
    Always upserts every product so image keys are set even on re-runs.
    Uses a deterministic product_id so re-runs overwrite rather than duplicate.
    """
    dynamodb = boto3.resource("dynamodb", region_name=region)
    table = dynamodb.Table(table_name)

    for p in products:
        pid = _stable_pid(table_name, p["name"])
        table.put_item(Item={
            "product_id":  pid,
            "name":        p["name"],
            "description": p["description"],
            "price":       p["price"],
            "image":       p["image"]        # S3 key — always written
        })
        print(f"Upserted: {p['name']} -> image={p['image']}")

# Image keys match exactly what Terraform uploads:
#   aws_s3_object key = "product-images/${each.value}"
# Django proxy serves them at /store/images/product-images/<filename>
SAMPLE_DATA = {
    "MenClothes": [
        {
            "name": "Classic Green Sweater",
            "description": "Warm knit sweater in forest green",
            "price": 69,
            "image": "product-images/men_classic_green_sweater_69.jpg"
        },
        {
            "name": "Classic White Shirt",
            "description": "Crisp cotton formal shirt",
            "price": 59,
            "image": "product-images/men_classic_white_shirt_59.jpg"
        },
        {
            "name": "Essential Polo Tshirt Set",
            "description": "Two-pack everyday polo tees",
            "price": 49,
            "image": "product-images/men_essential_polo_tshirt_set_49.jpg"
        },
    ],
    "WomenClothes": [
        {
            "name": "Leopard Mesh Top",
            "description": "Sheer mesh top, leopard print",
            "price": 49,
            "image": "product-images/women_leopard_mesh_top_49.jpg"
        },
        {
            "name": "Striped Sweatshirt",
            "description": "Relaxed-fit striped sweatshirt",
            "price": 39,
            "image": "product-images/women_striped_sweatshirt_39.jpg"
        },
        {
            "name": "White Ribbed Top",
            "description": "Fitted ribbed knit top",
            "price": 29,
            "image": "product-images/women_white_ribbed_top_29.jpg"
        },
    ],
    "KidsClothes": [
        {
            "name": "Christmas Sweater",
            "description": "Festive holiday knit",
            "price": 25,
            "image": "product-images/kids_christmas_sweater_25.jpg"
        },
        {
            "name": "Construction Print Sweatshirt",
            "description": "Diggers and trucks print",
            "price": 19,
            "image": "product-images/kids_construction_print_sweatshirt_19.jpg"
        },
        {
            "name": "Red Reindeer Sweatshirt",
            "description": "Red sweatshirt with reindeer",
            "price": 22,
            "image": "product-images/kids_red_reindeer_sweatshirt_22.jpg"
        },
    ],
}

def main():
    config = load_config()
    region = config["region"]
    tables = config["dynamodb_tables"]

    print("\nStarting EasyCart PRODUCT SETUP\n")
    for table_name in tables:
        create_table(region, table_name)
        seed_or_update_table(region, table_name, SAMPLE_DATA[table_name])

    print("\nDone — all products upserted with image keys.\n")

if __name__ == "__main__":
    main()