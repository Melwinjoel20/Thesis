
import json
import logging
import uuid

import boto3
from django.conf import settings
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_POST

_lambda_client = None

logger = logging.getLogger("easycart.cart")

_logs_client = None
_APP_LOG_GROUP = "/easycart/dev/app/correlation"
_APP_LOG_STREAM = "cart-service"
_log_stream_ready = False


def _logs():
    global _logs_client
    if _logs_client is None:
        from botocore.config import Config
        cfg = Config(connect_timeout=1, read_timeout=1, retries={"max_attempts": 0})
        _logs_client = boto3.client(
            "logs", region_name=settings.COGNITO["region"], config=cfg
        )
    return _logs_client


def _ensure_stream():
    global _log_stream_ready
    if _log_stream_ready:
        return
    try:
        _logs().create_log_stream(
            logGroupName=_APP_LOG_GROUP, logStreamName=_APP_LOG_STREAM
        )
    except _logs().exceptions.ResourceAlreadyExistsException:
        pass
    except Exception:
        pass
    _log_stream_ready = True


def _log_call(operation, user_id, status, correlation_id):
    record = json.dumps({
        "correlationId": correlation_id,
        "operation": operation,
        "userId": user_id or "anonymous",
        "status": status,
        "authenticated": bool(user_id),
    })
    logger.info(record)

    def _write():
        try:
            _ensure_stream()
            _logs().put_log_events(
                logGroupName=_APP_LOG_GROUP,
                logStreamName=_APP_LOG_STREAM,
                logEvents=[{
                    "timestamp": int(__import__("time").time() * 1000),
                    "message": record,
                }],
            )
        except Exception:
            pass

    import threading
    threading.Thread(target=_write, daemon=True).start()




def _client():
    global _lambda_client
    if _lambda_client is None:
        _lambda_client = boto3.client("lambda", region_name=settings.COGNITO["region"])
    return _lambda_client


def _function_name(key):
    name = settings.LAMBDA_FUNCTIONS.get(key)
    if not name:
        raise KeyError(f"lambda function '{key}' missing from config.json — re-run scripts/generate_config.py")
    return name


def _invoke(key, method="POST", body=None, query=None):
    """Invoke a Lambda with an API-Gateway-shaped event; return (status, dict)."""
    event = {
        "httpMethod": method,
        "body": json.dumps(body) if body is not None else None,
        "queryStringParameters": query,
        "requestContext": {},
    }
    resp = _client().invoke(
        FunctionName=_function_name(key),
        InvocationType="RequestResponse",
        Payload=json.dumps(event).encode(),
    )
    payload = json.loads(resp["Payload"].read() or b"{}")

    if resp.get("FunctionError"):
        print(f"Lambda {key} function error:", payload)
        return 502, {"error": "cart service error"}

    status = int(payload.get("statusCode", 200))
    raw = payload.get("body") or "{}"
    try:
        data = json.loads(raw)
    except (TypeError, ValueError):
        data = {"message": raw}
    return status, data


def _session_user(request):
    return request.session.get("user_id")


def _json_body(request):
    try:
        return json.loads(request.body or b"{}")
    except ValueError:
        return {}


def _relay(status, data):
    # Lambdas sometimes return bare lists (view-cart) — JsonResponse needs safe=False.
    return JsonResponse(data, status=status, safe=False)


@csrf_exempt
@require_POST
def add_to_cart(request):
    cid = str(uuid.uuid4())
    user_id = _session_user(request)
    if not user_id:
        _log_call("add-to-cart", None, 401, cid)
        return JsonResponse({"error": "Unauthorized: Please log in"}, status=401)
    body = _json_body(request)
    body["user_id"] = user_id  # identity from session, never the client
    status, data = _invoke("add-to-cart", body=body)
    _log_call("add-to-cart", user_id, status, cid)
    return _relay(status, data)


@require_GET
def view_cart(request):
    cid = str(uuid.uuid4())
    user_id = _session_user(request)
    if not user_id:
        _log_call("view-cart", None, 401, cid)
        return JsonResponse({"error": "Unauthorized: Please log in"}, status=401)
    status, data = _invoke("view-cart", method="GET", query={"user_id": user_id})
    _log_call("view-cart", user_id, status, cid)
    return _relay(status, data)


@csrf_exempt
@require_POST
def remove_cart_item(request):
    cid = str(uuid.uuid4())
    user_id = _session_user(request)
    if not user_id:
        _log_call("remove-cart-item", None, 401, cid)
        return JsonResponse({"error": "Unauthorized: Please log in"}, status=401)
    body = _json_body(request)
    body["user_id"] = user_id
    status, data = _invoke("remove-cart-item", body=body)
    _log_call("remove-cart-item", user_id, status, cid)
    return _relay(status, data)


@csrf_exempt
@require_POST
def place_order(request):
    cid = str(uuid.uuid4())
    user_id = _session_user(request)
    if not user_id:
        _log_call("place-order", None, 401, cid)
        return JsonResponse({"error": "Unauthorized: Please log in"}, status=401)
    body = _json_body(request)
    body["user_id"] = user_id
    status, data = _invoke("place-order", body=body)
    _log_call("place-order", user_id, status, cid)
    return _relay(status, data)


@csrf_exempt
@require_POST
def tax_calculator(request):
    # Pure computation — no user identity required.
    return _relay(*_invoke("tax-calculator", body=_json_body(request)))
