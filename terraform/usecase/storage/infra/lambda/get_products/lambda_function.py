import json
import boto3
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


def lambda_handler(event, context):
    """
    Return product catalogue items. This is the ONLY component that reads the
    product tables — Django invokes it via boto3 so the presentation tier has
    no direct DynamoDB path (R2).

    Accepts either a direct Django invoke ({"category": "..."}) or an API
    Gateway invoke (queryStringParameters). Omitting the category returns all
    categories.
    """
    print("Incoming event:", json.dumps(event))

    if "body" in event and event.get("body"):
        try:
            body = json.loads(event["body"])
        except Exception:
            body = {}
    else:
        body = event

    qs = event.get("queryStringParameters") or {}
    category = body.get("category") or qs.get("category")

    targets = [category] if category in CATEGORIES else CATEGORIES

    items = []
    try:
        for cat in targets:
            resp = dynamodb.Table(cat).scan()
            for item in resp.get("Items", []):
                item["category"] = cat
                items.append(item)
    except Exception as e:
        print("DynamoDB Error:", e)
        return {
            "statusCode": 500,
            "headers": _cors_headers(),
            "body": json.dumps({"error": "Failed to fetch products"}),
        }

    return {
        "statusCode": 200,
        "headers": _cors_headers(),
        "body": json.dumps(items, cls=DecimalEncoder),
    }
