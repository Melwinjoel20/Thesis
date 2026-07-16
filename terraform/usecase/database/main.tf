# =============================================================================
# Use Case: Database (Phase 3)
# Deploys all DynamoDB tables into the Database Spoke VPC.
# Private access only via VPC Gateway Endpoint — no public internet.
# =============================================================================
data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = var.STATE_BUCKET
    key    = "easycart/networking.tfstate"
    region = var.REGION
  }
}

module "dynamodb" {
  source = "../../modules/DynamoDB"

  product      = var.PRODUCT
  environment  = var.ENVIRONMENT
  region       = var.REGION
  region_short = var.REGION_SHORT
  name_prefix  = "db"
  name_suffix  = "001"

  tables = {
    "MenClothes"         = { hash_key = "product_id", hash_key_type = "S" }
    "WomenClothes"       = { hash_key = "product_id", hash_key_type = "S" }
    "KidsClothes"        = { hash_key = "product_id", hash_key_type = "S" }
    "UserCart"           = { hash_key = "user_id",    hash_key_type = "S", range_key = "item_id", range_key_type = "S" }
    "Orders"             = { hash_key = "order_id",   hash_key_type = "S" }
    "RateLimits"         = { hash_key = "key",        hash_key_type = "S" }
    "EasyCartAdminUsers" = { hash_key = "user_id",    hash_key_type = "S" }
  }

  vpc_id          = data.terraform_remote_state.networking.outputs.vpc_ids["database"]
  route_table_ids = values(data.terraform_remote_state.networking.outputs.route_table_ids["database"])

  extra_tags = merge(local.default_tags, {
    "Purpose" = "DynamoDB data layer"
    "Spoke"   = "Database"
  })
}
