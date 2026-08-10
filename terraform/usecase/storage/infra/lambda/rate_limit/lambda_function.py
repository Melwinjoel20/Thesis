import json
import time
import boto3
import os
from decimal import Decimal

dynamodb = boto3.resource("dynamodb")
TABLE_NAME = os.environ.get("RATE_LIMIT_TABLE", "RateLimits")
table = dynamodb.Table(TABLE_NAME)


def _check(key, limit, window):
    """
    Fixed-window rate limit, matching the original DynamoBackend/RateLimiter
    semantics. Returns True if allowed, False if the limit is exceeded.
    """
    res = table.get_item(Key={"key": key})
    record = res.get("Item")

    if not record:
        now = int(time.time())
        table.put_item(Item={"key": key, "count": Decimal(1), "ttl": now + window})
        return True

    count = int(record.get("count", 0))
    if count >= limit:
        return False

    table.update_item(
        Key={"key": key},
        UpdateExpression="SET #c = #c + :inc",
        ExpressionAttributeNames={"#c": "count"},
        ExpressionAttributeValues={":inc": Decimal(1)},
    )
    return True


def lambda_handler(event, context):
    print("Incoming event:", json.dumps(event))

    if "body" in event and event.get("body"):
        try:
            body = json.loads(event["body"])
        except Exception:
            body = {}
    else:
        body = event

    key = body.get("key")
    limit = int(body.get("limit", 5))
    window = int(body.get("window", 60))

    if not key:
        return {"statusCode": 400, "body": json.dumps({"error": "Missing key"})}

    try:
        allowed = _check(key, limit, window)
    except Exception as e:
        print("Rate limit error:", e)
        
        allowed = True

    return {"statusCode": 200, "body": json.dumps({"allowed": allowed})}
