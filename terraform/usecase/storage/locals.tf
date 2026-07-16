locals {
  default_tags = {
    "Environment" = var.ENVIRONMENT
    "Product"     = var.PRODUCT
    "Owner"       = "DevOps Team"
    "Project"     = "EasyCart"
    "CreatedBy"   = "Terraform"
    "Version"     = "1.0.0"
  }
}
