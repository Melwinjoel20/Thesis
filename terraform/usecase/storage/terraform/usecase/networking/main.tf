module "hub_vpc" {
  source = "../../modules/VPC"

  product      = var.PRODUCT
  environment  = var.ENVIRONMENT
  region_short = var.REGION_SHORT
  name_prefix  = var.HUB_VPC.name_prefix
  name_suffix  = var.HUB_VPC.name_suffix

  vpc_cidr   = var.HUB_VPC.vpc_cidr
  enable_igw = false # No IGW — fully private, access via SSM only

  subnets                  = var.HUB_VPC.subnets
  route_tables             = var.HUB_VPC.route_tables
  route_table_associations = var.HUB_VPC.route_table_associations

  extra_tags = merge(local.default_tags, {
    "Purpose" = "Hub VPC — Central Management and Ingress Plane"
  })
}

module "frontend_vpc" {
  source = "../../modules/VPC"

  product      = var.PRODUCT
  environment  = var.ENVIRONMENT
  region_short = var.REGION_SHORT
  name_prefix  = var.FRONTEND_VPC.name_prefix
  name_suffix  = var.FRONTEND_VPC.name_suffix

  vpc_cidr   = var.FRONTEND_VPC.vpc_cidr
  enable_igw = false

  subnets                  = var.FRONTEND_VPC.subnets
  route_tables             = var.FRONTEND_VPC.route_tables
  route_table_associations = var.FRONTEND_VPC.route_table_associations

  extra_tags = merge(local.default_tags, {
    "Purpose" = "Frontend Spoke VPC — Web Tier"
  })
}

module "app_vpc" {
  source = "../../modules/VPC"

  product      = var.PRODUCT
  environment  = var.ENVIRONMENT
  region_short = var.REGION_SHORT
  name_prefix  = var.APP_VPC.name_prefix
  name_suffix  = var.APP_VPC.name_suffix

  vpc_cidr   = var.APP_VPC.vpc_cidr
  enable_igw = false

  subnets                  = var.APP_VPC.subnets
  route_tables             = var.APP_VPC.route_tables
  route_table_associations = var.APP_VPC.route_table_associations

  extra_tags = merge(local.default_tags, {
    "Purpose" = "Application Spoke VPC — Microservices Tier"
  })
}

module "database_vpc" {
  source = "../../modules/VPC"

  product      = var.PRODUCT
  environment  = var.ENVIRONMENT
  region_short = var.REGION_SHORT
  name_prefix  = var.DATABASE_VPC.name_prefix
  name_suffix  = var.DATABASE_VPC.name_suffix

  vpc_cidr   = var.DATABASE_VPC.vpc_cidr
  enable_igw = false

  subnets                  = var.DATABASE_VPC.subnets
  route_tables             = var.DATABASE_VPC.route_tables
  route_table_associations = var.DATABASE_VPC.route_table_associations

  extra_tags = merge(local.default_tags, {
    "Purpose" = "Database Spoke VPC — Data Tier"
  })
}


module "transit_gateway" {
  source = "../../modules/TransitGateway"

  product      = var.PRODUCT
  environment  = var.ENVIRONMENT
  region_short = var.REGION_SHORT
  name_prefix  = var.TGW_NAME_PREFIX
  name_suffix  = var.TGW_NAME_SUFFIX

  vpc_attachments = {
    "hub" = {
      vpc_id     = module.hub_vpc.vpc_id
      subnet_ids = [module.hub_vpc.subnet_ids["tgw-subnet-a"]]
    }
    "frontend" = {
      vpc_id     = module.frontend_vpc.vpc_id
      subnet_ids = [module.frontend_vpc.subnet_ids["private-subnet-a"]]
    }
    "app" = {
      vpc_id     = module.app_vpc.vpc_id
      subnet_ids = [module.app_vpc.subnet_ids["private-subnet-a"]]
    }
    "database" = {
      vpc_id     = module.database_vpc.vpc_id
      subnet_ids = [module.database_vpc.subnet_ids["private-subnet-a"]]
    }
  }

  tgw_routes = {

    "hub-to-frontend" = {
      route_table_id   = module.hub_vpc.route_table_ids["private-rt"]
      destination_cidr = var.FRONTEND_VPC.vpc_cidr
    }
    "hub-to-app" = {
      route_table_id   = module.hub_vpc.route_table_ids["private-rt"]
      destination_cidr = var.APP_VPC.vpc_cidr
    }
    "hub-to-database" = {
      route_table_id   = module.hub_vpc.route_table_ids["private-rt"]
      destination_cidr = var.DATABASE_VPC.vpc_cidr
    }

    # ------------------------------------------------------------------
    # Frontend → hub + app  (NOT database)
    # ------------------------------------------------------------------
    "frontend-to-hub" = {
      route_table_id   = module.frontend_vpc.route_table_ids["private-rt"]
      destination_cidr = var.HUB_VPC.vpc_cidr
    }
    "frontend-to-app" = {
      route_table_id   = module.frontend_vpc.route_table_ids["private-rt"]
      destination_cidr = var.APP_VPC.vpc_cidr
    }

    # ------------------------------------------------------------------
    # App → hub + frontend + database  (central tier — talks to everyone)
    # ------------------------------------------------------------------
    "app-to-hub" = {
      route_table_id   = module.app_vpc.route_table_ids["private-rt"]
      destination_cidr = var.HUB_VPC.vpc_cidr
    }
    "app-to-frontend" = {
      route_table_id   = module.app_vpc.route_table_ids["private-rt"]
      destination_cidr = var.FRONTEND_VPC.vpc_cidr
    }
    "app-to-database" = {
      route_table_id   = module.app_vpc.route_table_ids["private-rt"]
      destination_cidr = var.DATABASE_VPC.vpc_cidr
    }

    # ------------------------------------------------------------------
    # Database → hub + app  (NOT frontend)
    # ------------------------------------------------------------------
    "database-to-hub" = {
      route_table_id   = module.database_vpc.route_table_ids["private-rt"]
      destination_cidr = var.HUB_VPC.vpc_cidr
    }
    "database-to-app" = {
      route_table_id   = module.database_vpc.route_table_ids["private-rt"]
      destination_cidr = var.APP_VPC.vpc_cidr
    }
  }

  extra_tags = merge(local.default_tags, {
    "Purpose" = "Transit Gateway — Hub and Spoke Routing"
  })

  depends_on = [
    module.hub_vpc,
    module.frontend_vpc,
    module.app_vpc,
    module.database_vpc
  ]
}


module "hub_endpoints" {
  source = "../../modules/SSMEndpoints"

  product       = var.PRODUCT
  environment   = var.ENVIRONMENT
  region        = var.REGION
  region_short  = var.REGION_SHORT
  name_prefix   = var.HUB_VPC.name_prefix
  name_suffix   = var.HUB_VPC.name_suffix
  vpc_id        = module.hub_vpc.vpc_id
  subnet_ids    = [module.hub_vpc.subnet_ids["hub-subnet-a"]]
  allowed_cidrs = [var.HUB_VPC.vpc_cidr]
  extra_tags    = local.default_tags
}

module "frontend_endpoints" {
  source = "../../modules/SSMEndpoints"

  product       = var.PRODUCT
  environment   = var.ENVIRONMENT
  region        = var.REGION
  region_short  = var.REGION_SHORT
  name_prefix   = var.FRONTEND_VPC.name_prefix
  name_suffix   = var.FRONTEND_VPC.name_suffix
  vpc_id        = module.frontend_vpc.vpc_id
  subnet_ids    = [module.frontend_vpc.subnet_ids["private-subnet-a"]]
  allowed_cidrs = [var.FRONTEND_VPC.vpc_cidr]
  extra_tags    = local.default_tags
}

module "app_endpoints" {
  source = "../../modules/SSMEndpoints"

  product       = var.PRODUCT
  environment   = var.ENVIRONMENT
  region        = var.REGION
  region_short  = var.REGION_SHORT
  name_prefix   = var.APP_VPC.name_prefix
  name_suffix   = var.APP_VPC.name_suffix
  vpc_id        = module.app_vpc.vpc_id
  subnet_ids    = [module.app_vpc.subnet_ids["private-subnet-a"]]
  allowed_cidrs = [var.APP_VPC.vpc_cidr]
  extra_tags    = local.default_tags
}

module "database_endpoints" {
  source = "../../modules/SSMEndpoints"

  product       = var.PRODUCT
  environment   = var.ENVIRONMENT
  region        = var.REGION
  region_short  = var.REGION_SHORT
  name_prefix   = var.DATABASE_VPC.name_prefix
  name_suffix   = var.DATABASE_VPC.name_suffix
  vpc_id        = module.database_vpc.vpc_id
  subnet_ids    = [module.database_vpc.subnet_ids["private-subnet-a"]]
  allowed_cidrs = [var.DATABASE_VPC.vpc_cidr]
  extra_tags    = local.default_tags
}

module "gateway_endpoints_hub" {
  source          = "../../modules/GatewayEndpoints"
  product         = var.PRODUCT
  environment     = var.ENVIRONMENT
  region          = var.REGION
  region_short    = var.REGION_SHORT
  name_prefix     = var.HUB_VPC.name_prefix
  name_suffix     = var.HUB_VPC.name_suffix
  vpc_id          = module.hub_vpc.vpc_id
  route_table_ids = values(module.hub_vpc.route_table_ids)
  service_names   = ["dynamodb", "s3"]
  extra_tags      = local.default_tags
}

module "gateway_endpoints_database" {
  source          = "../../modules/GatewayEndpoints"
  product         = var.PRODUCT
  environment     = var.ENVIRONMENT
  region          = var.REGION
  region_short    = var.REGION_SHORT
  name_prefix     = var.DATABASE_VPC.name_prefix
  name_suffix     = var.DATABASE_VPC.name_suffix
  vpc_id          = module.database_vpc.vpc_id
  route_table_ids = values(module.database_vpc.route_table_ids)
  service_names   = ["dynamodb"]
  extra_tags      = local.default_tags
}

# -----------------------------------------------------------------------------
# Hub — execute-api Interface endpoint (entry point for the internal private
# API Gateway; the API itself lives in the app layer). Reachable from every
# spoke over the TGW.
# -----------------------------------------------------------------------------
module "hub_api_ingress" {
  source = "../../modules/InterfaceEndpoints"

  product      = var.PRODUCT
  environment  = var.ENVIRONMENT
  region       = var.REGION
  region_short = var.REGION_SHORT
  name_prefix  = var.HUB_VPC.name_prefix
  name_suffix  = var.HUB_VPC.name_suffix

  vpc_id        = module.hub_vpc.vpc_id
  subnet_ids    = [values(module.hub_vpc.subnet_ids)[0]]
  service_names = ["execute-api"]
  allowed_cidrs = ["10.0.0.0/8"]

  # Cross-VPC callers use the endpoint-specific DNS name.
  private_dns_enabled = false

  extra_tags = local.default_tags
}

# -----------------------------------------------------------------------------
# Point-to-site VPN (AWS Client VPN) — optional, cost-bearing.
# Connect with the AWS VPN Client, then browse the app on its REAL domain:
# the EB CNAME resolves publicly to the internal ALB's private IPs, and the
# VPN provides the route. Toggle off when not demoing (~$0.15+/hr).
# -----------------------------------------------------------------------------
module "client_vpn" {
  count  = var.ENABLE_CLIENT_VPN ? 1 : 0
  source = "../../modules/ClientVpn"

  product      = var.PRODUCT
  environment  = var.ENVIRONMENT
  region       = var.REGION
  region_short = var.REGION_SHORT
  name_prefix  = var.HUB_VPC.name_prefix
  name_suffix  = var.HUB_VPC.name_suffix

  vpc_id                = module.hub_vpc.vpc_id
  association_subnet_id = values(module.hub_vpc.subnet_ids)[0]
  spoke_cidrs           = ["10.1.0.0/16", "10.2.0.0/16", "10.3.0.0/16"]
  vpc_dns_resolver      = "10.0.0.2"

  extra_tags = local.default_tags
}
