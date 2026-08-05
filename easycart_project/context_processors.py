from easycart_project.settings import generate_presigned_logo_url

def global_settings(request):
    return {
        "SIGNED_LOGO_URL": "/store/images/images/EasyCartLogo.png"
    }

def product_categories(request):
    return {
        "categories": ["Phones", "Laptops", "Accessories"]
    }
