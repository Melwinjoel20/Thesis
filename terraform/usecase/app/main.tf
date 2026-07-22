# =============================================================================
# Use Case: App (Phase 4)
# Deploys Lambda functions and Cognito into the App Spoke VPC.
# All Lambda functions run in private subnets — no public access.
# Cognito issues JWT tokens used by the frontend and verified by Lambda.
#
# Wiring:
#   - VPC / subnet / route table IDs come from usecase/networking remote state.
#   - The Lambda execution role is looked up by name (LabRole in Learner Lab).
#   - The order-notification SNS topic is created HERE (place-order publishes
#     to it), with an optional email subscription.
#   - Because the App VPC has no internet path, this stack also creates the
#     endpoints the functions need to reach AWS APIs:
#       * DynamoDB Gateway endpoint  (add/view/remove cart, place-order)
#       * SNS Interface endpoint     (place-order notifications)
#
# Run AFTER usecase/networking. Build the zips first: bash ../../lambda/build.sh
# =============================================================================

data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = var.STATE_BUCKET
    key    = "easycart/networking.tfstate"
    region = var.REGION
  }
}

# Learner Lab pre-creates LabRole — look it up instead of hardcoding the
# account ID in an ARN.
data "aws_iam_role" "lambda_exec" {
  name = var.LAMBDA_ROLE_NAME
}

# CIDR of the App VPC (for endpoint security group rules).
data "aws_vpc" "app" {
  id = local.app_vpc_id
}

# -----------------------------------------------------------------------------
# SNS — order notifications (published by place-order)
# -----------------------------------------------------------------------------
resource "aws_sns_topic" "orders" {
  name = "EasyCartOrderNotifications"

  tags = merge(local.default_tags, {
    "Purpose" = "SNS - order placed notifications"
    "Spoke"   = "App"
  })
}

resource "aws_sns_topic_subscription" "orders_email" {
  count = var.ORDER_NOTIFICATION_EMAIL != "" ? 1 : 0

  topic_arn = aws_sns_topic.orders.arn
  protocol  = "email"
  endpoint  = var.ORDER_NOTIFICATION_EMAIL
}

# -----------------------------------------------------------------------------
# Security groups
# -----------------------------------------------------------------------------
# Lambda functions only make outbound calls (DynamoDB, SNS) — no ingress.
resource "aws_security_group" "lambda" {
  name        = "app-sg-lambda-${var.PRODUCT}-${var.ENVIRONMENT}-${var.REGION_SHORT}-001"
  description = "EasyCart Lambda functions - egress only"
  vpc_id      = local.app_vpc_id

  egress {
    description = "All outbound (reaches AWS APIs via VPC endpoints)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags, {
    Name    = "app-sg-lambda-${var.PRODUCT}-${var.ENVIRONMENT}-${var.REGION_SHORT}-001"
    "Spoke" = "App"
  })
}

# Interface endpoints accept HTTPS from inside the App VPC.
resource "aws_security_group" "vpce" {
  name        = "app-sg-vpce-${var.PRODUCT}-${var.ENVIRONMENT}-${var.REGION_SHORT}-001"
  description = "HTTPS from App VPC to interface endpoints"
  vpc_id      = local.app_vpc_id

  ingress {
    description = "HTTPS from App VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.app.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.default_tags, {
    Name    = "app-sg-vpce-${var.PRODUCT}-${var.ENVIRONMENT}-${var.REGION_SHORT}-001"
    "Spoke" = "App"
  })
}

# -----------------------------------------------------------------------------
# VPC endpoints — the App VPC is fully private, so AWS APIs must be reachable
# through endpoints or every boto3 call inside Lambda will time out.
# -----------------------------------------------------------------------------
module "dynamodb_endpoint" {
  source = "../../modules/GatewayEndpoints"

  product      = var.PRODUCT
  environment  = var.ENVIRONMENT
  region       = var.REGION
  region_short = var.REGION_SHORT
  name_prefix  = "app"
  name_suffix  = "001"

  vpc_id          = local.app_vpc_id
  route_table_ids = values(data.terraform_remote_state.networking.outputs.route_table_ids["app"])
  service_names   = ["dynamodb"]

  extra_tags = merge(local.default_tags, {
    "Purpose" = "DynamoDB access for Lambda in private subnets"
    "Spoke"   = "App"
  })
}

resource "aws_vpc_endpoint" "sns" {
  vpc_id              = local.app_vpc_id
  service_name        = "com.amazonaws.${var.REGION}.sns"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.app_subnet_ids
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true

  tags = merge(local.default_tags, {
    Name    = "app-vpce-sns-${var.PRODUCT}-${var.ENVIRONMENT}-${var.REGION_SHORT}-001"
    "Spoke" = "App"
  })
}

# -----------------------------------------------------------------------------
# Cognito — OAuth 2.0 identity
# -----------------------------------------------------------------------------
module "cognito" {
  source = "../../modules/Cognito"

  product      = var.PRODUCT
  environment  = var.ENVIRONMENT
  region_short = var.REGION_SHORT
  name_prefix  = "app"
  name_suffix  = "001"

  extra_tags = merge(local.default_tags, {
    "Purpose" = "Cognito - OAuth 2.0 identity for EasyCart"
    "Spoke"   = "App"
  })
}

# -----------------------------------------------------------------------------
# Lambda — EasyCart microservices (private subnets, no public access)
# -----------------------------------------------------------------------------
module "lambda" {
  source = "../../modules/Lambda"

  product      = var.PRODUCT
  environment  = var.ENVIRONMENT
  region       = var.REGION
  region_short = var.REGION_SHORT
  name_prefix  = "app"
  name_suffix  = "001"

  lambda_role_arn   = data.aws_iam_role.lambda_exec.arn
  subnet_ids        = local.app_subnet_ids
  security_group_id = aws_security_group.lambda.id

  functions = {
    "add-to-cart" = {
      zip_path = "${var.LAMBDA_ZIP_DIR}/add_to_cart.zip"
      env_vars = { CART_TABLE = "UserCart" }
    }
    "view-cart" = {
      zip_path = "${var.LAMBDA_ZIP_DIR}/view_cart.zip"
      env_vars = { CART_TABLE = "UserCart" }
    }
    "remove-cart-item" = {
      zip_path = "${var.LAMBDA_ZIP_DIR}/remove_cart_item.zip"
      env_vars = { CART_TABLE = "UserCart" }
    }
    "place-order" = {
      zip_path = "${var.LAMBDA_ZIP_DIR}/place_order.zip"
      env_vars = {
        ORDERS_TABLE  = "Orders"
        SNS_TOPIC_ARN = aws_sns_topic.orders.arn
      }
    }
    "tax-calculator" = {
      zip_path = "${var.LAMBDA_ZIP_DIR}/tax_calculator.zip"
      env_vars = {}
    }
  }

  extra_tags = merge(local.default_tags, {
    "Purpose" = "Lambda - EasyCart microservices"
    "Spoke"   = "App"
  })
}

# -----------------------------------------------------------------------------
# Internal API — private, JWT-authenticated door to the same Lambdas
# (network entry point — the hub execute-api endpoint — is owned by the
# networking layer; this layer decides what sits behind it)
# -----------------------------------------------------------------------------
module "internal_api" {
  source = "../../modules/InternalApi"

  product      = var.PRODUCT
  environment  = var.ENVIRONMENT
  region       = var.REGION
  region_short = var.REGION_SHORT
  name_prefix  = "app"
  name_suffix  = "001"

  user_pool_arn   = module.cognito.user_pool_arn
  vpc_endpoint_id = data.terraform_remote_state.networking.outputs.execute_api_endpoint_id

  # Identity-attributed access logging (service + authentication layers)
  access_log_group_arn = data.terraform_remote_state.networking.outputs.api_access_log_group_arn

  functions = {
    for key, name in module.lambda.function_names : key => {
      function_name = name
      invoke_arn    = module.lambda.invoke_arns[key]
    }
  }

  extra_tags = merge(local.default_tags, { "Spoke" = "App" })
}
