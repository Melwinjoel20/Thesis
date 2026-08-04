# =============================================================================
# Use Case: Storage (Phase 2)
# Deploys the private S3 bucket into the Hub VPC via VPC Endpoint.
# No public access — replaces the public bucket from create_s3.py
#
# All VPC / route table IDs come from the networking layer via remote state
# — apply usecase/networking first, nothing to copy-paste here.
# =============================================================================

data "aws_caller_identity" "current" {}

data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "easycart-tfstate-${data.aws_caller_identity.current.account_id}"
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

# Upload product images at deploy time.
# fileset() lists every file under infra/product_images; etag ensures
# Terraform only re-uploads when a file's content changes.
locals {
  image_dir = "${path.root}/../../infra/product_images"
}

resource "aws_s3_object" "product_images" {
  for_each = fileset(local.image_dir, "*.{jpg,jpeg,png,gif,webp}")

  bucket       = module.s3.bucket_name
  key          = "product-images/${each.value}"
  source       = "${local.image_dir}/${each.value}"
  etag         = filemd5("${local.image_dir}/${each.value}")
  content_type = "image/jpeg"

  tags = merge(local.default_tags, {
    "Purpose" = "Product image"
  })
}

# Upload the logo the same way.
resource "aws_s3_object" "logo" {
  bucket       = module.s3.bucket_name
  key          = "images/EasyCartLogo.png"
  source       = "${path.root}/../../infra/EasyCartLogo.png"
  etag         = filemd5("${path.root}/../../infra/EasyCartLogo.png")
  content_type = "image/png"

  tags = merge(local.default_tags, {
    "Purpose" = "Logo"
  })
}