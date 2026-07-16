locals {
  default_tags = {
    "Environment" = var.ENVIRONMENT
    "Product"     = var.PRODUCT
    "Owner"       = "DevOps Team"
    "Project"     = "EasyCart"
    "CreatedBy"   = "Terraform"
    "Version"     = "1.0.0"
  }

  # Aliases over networking remote state outputs.
  app_vpc_id     = data.terraform_remote_state.networking.outputs.vpc_ids["app"]
  app_subnet_ids = values(data.terraform_remote_state.networking.outputs.subnet_ids["app"])
}
