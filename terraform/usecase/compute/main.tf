# =============================================================================
# Use Case: Compute
#
# Deploys one private EC2 test instance per VPC.
# All instance and subnet IDs come from the networking layer via remote state
# — no IDs are hardcoded here.
#
# Access: SSM Session Manager only (no public IP, no key pair, no port 22).
# Test:   ping between instances to verify TGW routing and segmentation.
#
# Destroy this layer freely to save Learner Lab budget — the networking layer
# (VPCs, TGW, endpoints) stays untouched and can be reused when you come back.
# =============================================================================

# -----------------------------------------------------------------------------
# Hub — management and ingress plane
# SSM into this instance first, then ping the spokes from here.
# -----------------------------------------------------------------------------
module "hub_ec2" {
  source = "../../modules/Compute"

  product          = var.PRODUCT
  environment      = var.ENVIRONMENT
  region_short     = var.REGION_SHORT
  name_prefix      = "hub"
  name_suffix      = "001"
  vpc_id           = local.vpc_ids["hub"]
  subnet_id        = local.subnet_ids["hub"]["hub-subnet-a"]
  ami              = data.aws_ami.al2023.id
  instance_type    = var.INSTANCE_TYPE
  instance_profile = var.INSTANCE_PROFILE
  icmp_cidrs       = var.PING_CIDRS
  extra_tags       = local.default_tags
}

# -----------------------------------------------------------------------------
# Frontend spoke — web tier
# -----------------------------------------------------------------------------
module "frontend_ec2" {
  source = "../../modules/Compute"

  product          = var.PRODUCT
  environment      = var.ENVIRONMENT
  region_short     = var.REGION_SHORT
  name_prefix      = "fe"
  name_suffix      = "001"
  vpc_id           = local.vpc_ids["frontend"]
  subnet_id        = local.subnet_ids["frontend"]["private-subnet-a"]
  ami              = data.aws_ami.al2023.id
  instance_type    = var.INSTANCE_TYPE
  instance_profile = var.INSTANCE_PROFILE
  icmp_cidrs       = var.PING_CIDRS
  extra_tags       = local.default_tags
}

# -----------------------------------------------------------------------------
# App spoke — microservices tier
# -----------------------------------------------------------------------------
module "app_ec2" {
  source = "../../modules/Compute"

  product          = var.PRODUCT
  environment      = var.ENVIRONMENT
  region_short     = var.REGION_SHORT
  name_prefix      = "app"
  name_suffix      = "001"
  vpc_id           = local.vpc_ids["app"]
  subnet_id        = local.subnet_ids["app"]["private-subnet-a"]
  ami              = data.aws_ami.al2023.id
  instance_type    = var.INSTANCE_TYPE
  instance_profile = var.INSTANCE_PROFILE
  icmp_cidrs       = var.PING_CIDRS
  extra_tags       = local.default_tags
}

# -----------------------------------------------------------------------------
# Database spoke — data tier
# -----------------------------------------------------------------------------
module "database_ec2" {
  source = "../../modules/Compute"

  product          = var.PRODUCT
  environment      = var.ENVIRONMENT
  region_short     = var.REGION_SHORT
  name_prefix      = "db"
  name_suffix      = "001"
  vpc_id           = local.vpc_ids["database"]
  subnet_id        = local.subnet_ids["database"]["private-subnet-a"]
  ami              = data.aws_ami.al2023.id
  instance_type    = var.INSTANCE_TYPE
  instance_profile = var.INSTANCE_PROFILE
  icmp_cidrs       = var.PING_CIDRS
  extra_tags       = local.default_tags
}
