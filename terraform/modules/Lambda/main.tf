# =============================================================================
# Module: Lambda
# Description: Creates all Lambda functions inside the App Spoke VPC
#              private subnet. Functions are not publicly accessible.
#              Traffic from frontend reaches them via PrivateLink / TGW through Hub.
#              Matches the lambda/ functions: add_to_cart, view_cart,
#              remove_cart_item, place_order, tax_calculator.
# =============================================================================

# -----------------------------------------------------------------------------
# Lambda Functions — created dynamically from the functions map
# -----------------------------------------------------------------------------
resource "aws_lambda_function" "this" {
  for_each = var.functions

  function_name = "${var.name_prefix}-fn-${each.key}-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  description   = "EasyCart Lambda — ${each.key}"
  role          = var.lambda_role_arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 256

  filename         = each.value.zip_path
  source_code_hash = filebase64sha256(each.value.zip_path)

  # Deploy inside App Spoke VPC private subnet — no public access
  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  environment {
    variables = merge(
      {
        ENVIRONMENT = var.environment
        REGION      = var.region
      },
      lookup(each.value, "env_vars", {})
    )
  }

  tags = merge(var.extra_tags, {
    Name = "${var.name_prefix}-fn-${each.key}-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  })
}
