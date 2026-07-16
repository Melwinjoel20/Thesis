# =============================================================================
# Use Case: Storage (Phase 2)
# Deploys the private S3 bucket into the Hub VPC via VPC Endpoint.
# No public access — replaces the public bucket from create_s3.py
#
# All VPC / route table IDs come from the networking layer via remote state
# — apply usecase/networking first, nothing to copy-paste here.
# =============================================================================

data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = var.STATE_BUCKET
    key    = "easycart/networking.tfstate"
    region = var.REGION
  }
}

module "s3" {
  source = "../../modules/S3"

  product      = var.PRODUCT
  environment  = var.ENVIRONMENT
  region       = var.REGION
  region_short = var.REGION_SHORT
  name_prefix  = "hub"
  name_suffix  = "001"

  bucket_name     = var.S3_BUCKET_NAME
  vpc_id          = data.terraform_remote_state.networking.outputs.vpc_ids["hub"]
  route_table_ids = values(data.terraform_remote_state.networking.outputs.route_table_ids["hub"])

  # networking's gateway_endpoints_hub already puts an S3 gateway endpoint in
  # the hub VPC — creating a second one fails with RouteAlreadyExists.
  create_vpc_endpoint = false

  extra_tags = merge(local.default_tags, {
    "Purpose" = "Private S3 - Product images and logo"
    "Spoke"   = "Hub"
  })
}
