locals {
  default_tags = {
    "Environment" = var.ENVIRONMENT
    "Product"     = var.PRODUCT
    "Owner"       = "DevOps Team"
    "Project"     = "EasyCart"
    "CreatedBy"   = "Terraform"
    "Version"     = "1.0.0"
  }

  image_dir = "${path.module}/../../../infra/product_images"
  logo_path = "${path.module}/../../../infra/EasyCartLogo.png"
}