import json
import uuid
import boto3
from django.conf import settings
from django.shortcuts import render, redirect
from django.contrib import messages
from .views import admin_required, _invoke_lambda

# =========================
# CONFIG
# =========================
REGION = settings.S3_REGION
BUCKET = settings.S3_BUCKET


# =========================
# ADMIN DASHBOARD
# =========================
@admin_required
def admin_dashboard(request):
    return render(request, "admin/admin_dashboard.html")


# =========================
# HELPER: UPLOAD IMAGE TO S3 (server-side, via S3 gateway endpoint - R7)
# =========================
def upload_product_image_to_s3(file_obj):
    """
    Server-side upload through the frontend VPC's S3 gateway endpoint.
    Returns the S3 key (not a URL). Images are served back to browsers via
    the private Django proxy (store/views.serve_image), never a public URL.
    """
    s3 = boto3.client("s3", region_name=REGION)
    ext = file_obj.name.split(".")[-1]
    key = f"product-images/{uuid.uuid4()}.{ext}"
    try:
        s3.upload_fileobj(
            file_obj,
            BUCKET,
            key,
            ExtraArgs={"ContentType": file_obj.content_type},
        )
        return key
    except Exception as e:
        print("S3 Upload Error:", e)
        return None


# =========================
# ADD PRODUCT  (via manage-products Lambda - no direct DynamoDB, R2)
# =========================
@admin_required
def admin_add_product(request):
    categories = settings.COGNITO.get("dynamodb_tables", [])

    if request.method == "POST":
        category = request.POST.get("category")
        name = request.POST.get("name")
        description = request.POST.get("description")
        price = request.POST.get("price")
        image_file = request.FILES.get("image_file")

        if category not in categories:
            messages.error(request, "Invalid category selected.")
            return redirect("admin_add_product")

        if not image_file:
            messages.error(request, "Please upload an image.")
            return redirect("admin_add_product")

        s3_key = upload_product_image_to_s3(image_file)
        if not s3_key:
            messages.error(request, "Failed to upload image to S3.")
            return redirect("admin_add_product")

        try:
            status, body = _invoke_lambda("manage-products", {
                "action": "add",
                "category": category,
                "name": name,
                "description": description,
                "price": float(price),
                "image": s3_key,
            })
            if status != 200:
                raise RuntimeError(body.get("error", "add failed"))
        except Exception as e:
            messages.error(request, f"Failed to add product: {e}")
            return redirect("admin_add_product")

        messages.success(request, "Product added successfully!")
        return redirect("admin_dashboard")

    return render(request, "admin/add_product.html", {"categories": categories})


# =========================
# VIEW / LIST ALL PRODUCTS  (via manage-products Lambda - R2)
# =========================
@admin_required
def admin_manage_products(request):
    categories = settings.COGNITO.get("dynamodb_tables", [])
    products = []
    try:
        status, body = _invoke_lambda("manage-products", {"action": "list"})
        if status == 200 and isinstance(body, list):
            products = body
    except Exception as e:
        messages.error(request, f"Failed to load products: {e}")

    return render(request, "admin/manage_products.html", {
        "products": products,
        "categories": categories,
    })


# =========================
# DELETE PRODUCT  (via manage-products Lambda - R2)
# =========================
@admin_required
def admin_delete_product(request, category, product_id):
    try:
        status, body = _invoke_lambda("manage-products", {
            "action": "delete",
            "category": category,
            "product_id": product_id,
        })
        if status != 200:
            raise RuntimeError(body.get("error", "delete failed"))
        image_key = body.get("image_key")
    except Exception as e:
        messages.error(request, f"Failed to delete product: {e}")
        return redirect("admin_manage_products")

    # Remove the image object server-side via the S3 gateway endpoint.
    if image_key:
        try:
            s3 = boto3.client("s3", region_name=REGION)
            s3.delete_object(Bucket=BUCKET, Key=image_key)
        except Exception as e:
            print("S3 delete failed:", e)
            messages.warning(request, "Product deleted, but image could not be removed.")

    messages.success(request, "Product removed successfully!")
    return redirect("admin_manage_products")
