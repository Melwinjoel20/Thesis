# =============================================================================
# Use Case: Frontend (Phase 5)
# Deploys Elastic Beanstalk into the Frontend Spoke VPC.
# Internal ALB only — no public endpoint. Reached from the Hub via TGW.
#
# Wiring:
#   - VPC / subnet IDs come from usecase/networking remote state.
#   - Creates the instance security group (HTTP from Hub + App CIDRs).
#   - The Frontend VPC has NO internet path, so this stack creates the
#     endpoints the EB agent needs to bootstrap and report health:
#       * S3 Gateway endpoint (platform assets + app bundle)
#       * Interface endpoints: elasticbeanstalk, elasticbeanstalk-health,
#         cloudformation, sqs
#     Without these the environment hangs in "Launching" and times out.
#
# Run AFTER usecase/networking.
# =============================================================================

data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = var.STATE_BUCKET
    key    = "easycart/networking.tfstate"
    region = var.REGION
  }
}

data "aws_vpc" "frontend" {
  id = local.frontend_vpc_id
}

# -----------------------------------------------------------------------------
# Security groups
# -----------------------------------------------------------------------------
resource "aws_security_group" "eb_instances" {
  name        = "fe-sg-eb-${var.PRODUCT}-${var.ENVIRONMENT}-${var.REGION_SHORT}-001"
  description = "EasyCart EB instances - HTTP from Hub and App spokes only"
  vpc_id      = local.frontend_vpc_id

  ingress {
    description = "HTTP from Hub and App VPCs via TGW"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.ALLOWED_INGRESS_CIDRS
  }

  ingress {
    description = "HTTPS from Hub and App VPCs via TGW"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.ALLOWED_INGRESS_CIDRS
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags, {
    Name    = "fe-sg-eb-${var.PRODUCT}-${var.ENVIRONMENT}-${var.REGION_SHORT}-001"
    "Spoke" = "Frontend"
  })
}

resource "aws_security_group" "vpce" {
  name        = "fe-sg-vpce-${var.PRODUCT}-${var.ENVIRONMENT}-${var.REGION_SHORT}-001"
  description = "HTTPS from Frontend VPC to interface endpoints"
  vpc_id      = local.frontend_vpc_id

  ingress {
    description = "HTTPS from Frontend VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.frontend.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags, {
    Name    = "fe-sg-vpce-${var.PRODUCT}-${var.ENVIRONMENT}-${var.REGION_SHORT}-001"
    "Spoke" = "Frontend"
  })
}

# -----------------------------------------------------------------------------
# VPC endpoints required by the Elastic Beanstalk agent in a private VPC
# -----------------------------------------------------------------------------
module "s3_endpoint" {
  source = "../../modules/GatewayEndpoints"

  product      = var.PRODUCT
  environment  = var.ENVIRONMENT
  region       = var.REGION
  region_short = var.REGION_SHORT
  name_prefix  = "fe"
  name_suffix  = "001"

  vpc_id          = local.frontend_vpc_id
  route_table_ids = values(data.terraform_remote_state.networking.outputs.route_table_ids["frontend"])
  service_names   = ["s3", "dynamodb"] # dynamodb: Django reads products/admin/rate-limit tables directly

  extra_tags = merge(local.default_tags, {
    "Purpose" = "S3 access for EB platform assets and app bundles"
    "Spoke"   = "Frontend"
  })
}

resource "aws_vpc_endpoint" "eb_interface" {
  for_each = toset([
    "elasticbeanstalk",
    "elasticbeanstalk-health",
    "cloudformation",
    "sqs",
    "cognito-idp", # Django login/register/OTP via cognito-idp SDK
  ])

  vpc_id              = local.frontend_vpc_id
  service_name        = "com.amazonaws.${var.REGION}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.frontend_subnet_ids
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true

  tags = merge(local.default_tags, {
    Name    = "fe-vpce-${each.value}-${var.PRODUCT}-${var.ENVIRONMENT}-${var.REGION_SHORT}-001"
    "Spoke" = "Frontend"
  })
}

# -----------------------------------------------------------------------------
# Elastic Beanstalk — EasyCart frontend
# -----------------------------------------------------------------------------
module "elastic_beanstalk" {
  source = "../../modules/ElasticBeanstalk"

  product      = var.PRODUCT
  environment  = var.ENVIRONMENT
  region_short = var.REGION_SHORT
  name_prefix  = "fe"
  name_suffix  = "001"

  solution_stack_name = var.EB_SOLUTION_STACK
  environment_type    = "SingleInstance"
  instance_type       = "t3.micro"
  service_role        = var.EB_SERVICE_ROLE
  instance_profile    = var.EB_INSTANCE_PROFILE

  vpc_id            = local.frontend_vpc_id
  subnet_ids        = local.frontend_subnet_ids
  security_group_id = aws_security_group.eb_instances.id

  extra_tags = merge(local.default_tags, {
    "Purpose" = "Elastic Beanstalk - EasyCart frontend app"
    "Spoke"   = "Frontend"
  })

  depends_on = [
    module.s3_endpoint,
    aws_vpc_endpoint.eb_interface,
  ]
}
