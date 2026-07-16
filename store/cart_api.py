"""
Server-side cart API — Django proxies to the private Lambda functions.

The browser calls these local endpoints (same origin, session-authenticated);
Django invokes the corresponding Lambda through the frontend VPC's Lambda
interface endpoint and relays the JSON response. No API Gateway, no public
Lambda surface — the zero-trust replacement for the old
https://...execute-api.../prod/* endpoints.

Each Lambda already speaks API-Gateway-proxy shape (httpMethod, body,
queryStringParameters -> {statusCode, body}), so we wrap requests in that
event format and unwrap the response.

Security model: identity comes from the Django session (set at login), never
from the client payload — user_id in the body is overwritten server-side.
CSRF is exempted on these JSON endpoints because the legacy templates POST
without a CSRF token (they were built for API Gateway + JWT); the session
cookie's SameSite=Lax plus the JSON content type limit the practical risk
for this project.
"""

import json

import boto3
from django.conf import settings
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_POST

_lambda_client = None


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
    user_id = _session_user(request)
    if not user_id:
        return JsonResponse({"error": "Unauthorized: Please log in"}, status=401)
    body = _json_body(request)
    body["user_id"] = user_id  # identity from session, never the client
    return _relay(*_invoke("add-to-cart", body=body))


@require_GET
def view_cart(request):
    user_id = _session_user(request)
    if not user_id:
        return JsonResponse({"error": "Unauthorized: Please log in"}, status=401)
    return _relay(*_invoke("view-cart", method="GET", query={"user_id": user_id}))


@csrf_exempt
@require_POST
def remove_cart_item(request):
    user_id = _session_user(request)
    if not user_id:
        return JsonResponse({"error": "Unauthorized: Please log in"}, status=401)
    body = _json_body(request)
    body["user_id"] = user_id
    return _relay(*_invoke("remove-cart-item", body=body))


@csrf_exempt
@require_POST
def place_order(request):
    user_id = _session_user(request)
    if not user_id:
        return JsonResponse({"error": "Unauthorized: Please log in"}, status=401)
    body = _json_body(request)
    body["user_id"] = user_id
    return _relay(*_invoke("place-order", body=body))


@csrf_exempt
@require_POST
def tax_calculator(request):
    # Pure computation — no user identity required.
    return _relay(*_invoke("tax-calculator", body=_json_body(request)))
