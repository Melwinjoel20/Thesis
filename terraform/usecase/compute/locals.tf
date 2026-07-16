locals {
  default_tags = {
    "Environment" = var.ENVIRONMENT
    "Product"     = var.PRODUCT
    "Owner"       = "DevOps Team"
    "Project"     = "Zero Trust Private Cloud - AWS"
    "CreatedBy"   = "Terraform"
    "CreatedOn"   = formatdate("YYYY-MM-DD", timestamp())
    "Version"     = "1.0.0"
    "Layer"       = "compute"
  }

  # Pull networking outputs into local values for cleaner references below.
  # Instead of writing data.terraform_remote_state.networking.outputs.vpc_ids["hub"]
  # everywhere, we alias them here.
  vpc_ids    = data.terraform_remote_state.networking.outputs.vpc_ids
  subnet_ids = data.terraform_remote_state.networking.outputs.subnet_ids
}
