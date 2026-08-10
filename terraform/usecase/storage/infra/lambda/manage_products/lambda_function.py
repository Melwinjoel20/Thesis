import json
import boto3
import uuid
from decimal import Decimal

dynamodb = boto3.resource("dynamodb")

CATEGORIES = ["MenClothes", "WomenClothes", "KidsClothes"]


class DecimalEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, Decimal):
            return int(o) if o % 1 == 0 else float(o)
        return super().default(o)


def _cors_headers():
    return {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
        "Access-Control-Allow-Headers": "*",
        "Content-Type": "application/json",
    }


def _resp(code, payload):
    return {
        "statusCode": code,
        "headers": _cors_headers(),
        "body": json.dumps(payload, cls=DecimalEncoder),
    }


def lambda_handler(event, context):
    """
    Admin product operations: list, add, delete. Django's admin views invoke
    this instead of touching DynamoDB directly, so the presentation tier has
    no direct data-tier path (R2). Image objects in S3 are managed separately
    by the Django proxy / Terraform; this function only records or removes the
    image KEY in the product item.
    """
    print("Incoming event:", json.dumps(event))

    if "body" in event and event.get("body"):
        try:
            body = json.loads(event["body"])
        except Exception:
            body = {}
    else:
        body = event

    action = body.get("action")

    # list spans all categories, so it doesn't require a valid category up front
    if action == "list":
        items = []
        for cat in CATEGORIES:
            for item in dynamodb.Table(cat).scan().get("Items", []):
                item["category"] = cat
                items.append(item)
        return _resp(200, items)

    category = body.get("category")
    if category not in CATEGORIES:
        return _resp(400, {"error": "Invalid category"})

    table = dynamodb.Table(category)

    if action == "add":
        name = body.get("name")
        description = body.get("description", "")
        price = body.get("price")
        image = body.get("image", "")
        if not name or price is None:
            return _resp(400, {"error": "Missing name or price"})
        pid = str(uuid.uuid4())
        table.put_item(Item={
            "product_id": pid,
            "name": name,
            "description": description,
            "price": Decimal(str(price)),
            "image": image,
        })
        return _resp(200, {"message": "Product added", "product_id": pid})

    if action == "delete":
        product_id = body.get("product_id")
        if not product_id:
            return _resp(400, {"error": "Missing product_id"})
        res = table.get_item(Key={"product_id": product_id})
        item = res.get("Item")
        if not item:
            return _resp(404, {"error": "Product not found"})
        image_key = item.get("image")
        table.delete_item(Key={"product_id": product_id})
        return _resp(200, {"message": "Product deleted", "image_key": image_key})

    return _resp(400, {"error": "Unknown action"})
