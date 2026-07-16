locals {
  default_tags = {
    "Environment" = var.ENVIRONMENT
    "Product"     = var.PRODUCT
    "Owner"       = "DevOps Team"
    "Project"     = "Zero Trust Private Cloud - AWS"
    "CreatedBy"   = "Terraform"
    "CreatedOn"   = formatdate("YYYY-MM-DD", timestamp())
    "Version"     = "1.0.0"
  }
}
