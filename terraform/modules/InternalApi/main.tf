# =============================================================================
# Module: InternalApi
# Description: PRIVATE REST API Gateway + Cognito JWT authorizer fronting a
#              set of Lambda functions. No internet presence: only requests
#              arriving through the given execute-api VPC endpoint (owned by
#              the networking layer) are accepted, and every route requires
#              a valid Cognito ID token before the Lambda is invoked.
# =============================================================================

resource "aws_api_gateway_rest_api" "this" {
  name        = "${var.name_prefix}-api-internal-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  description = "Internal JWT-authenticated API (${var.product})"

  endpoint_configuration {
    types            = ["PRIVATE"]
    vpc_endpoint_ids = [var.vpc_endpoint_id]
  }

  tags = var.extra_tags
}

# Only requests arriving through OUR endpoint are allowed.
resource "aws_api_gateway_rest_api_policy" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "${aws_api_gateway_rest_api.this.execution_arn}/*"
        Condition = { StringEquals = { "aws:SourceVpce" = var.vpc_endpoint_id } }
      },
      {
        Effect    = "Deny"
        Principal = "*"
        Action    = "execute-api:Invoke"
        Resource  = "${aws_api_gateway_rest_api.this.execution_arn}/*"
        Condition = { StringNotEquals = { "aws:SourceVpce" = var.vpc_endpoint_id } }
      }
    ]
  })
}

resource "aws_api_gateway_authorizer" "cognito" {
  name            = "cognito-jwt"
  rest_api_id     = aws_api_gateway_rest_api.this.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [var.user_pool_arn]
  identity_source = "method.request.header.Authorization"
}

resource "aws_api_gateway_resource" "fn" {
  for_each    = var.functions
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = each.key
}

resource "aws_api_gateway_method" "fn" {
  for_each      = var.functions
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.fn[each.key].id
  http_method   = "ANY"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "fn" {
  for_each                = var.functions
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.fn[each.key].id
  http_method             = aws_api_gateway_method.fn[each.key].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = each.value.invoke_arn
}

resource "aws_lambda_permission" "api" {
  for_each      = var.functions
  statement_id  = "AllowInternalApiInvoke"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*/${each.key}"
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeploy = sha1(jsonencode([
      aws_api_gateway_rest_api_policy.this.policy,
      [for k in sort(keys(var.functions)) : aws_api_gateway_integration.fn[k].uri],
      aws_api_gateway_authorizer.cognito.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_api_gateway_integration.fn, aws_api_gateway_rest_api_policy.this]
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.stage_name

  xray_tracing_enabled = true

  # Private-endpoint access log. The authoriser claims are emitted alongside
  # the network 5-tuple context, which is what allows a request arriving
  # through the VPC endpoint to be attributed to a verified identity rather
  # than only to a source address.
  dynamic "access_log_settings" {
    for_each = var.access_log_group_arn != "" ? [1] : []
    content {
      destination_arn = var.access_log_group_arn
      format = jsonencode({
        requestId       = "$context.requestId"
        correlationId   = "$context.requestOverride.header.X-Correlation-Id"
        requestTime     = "$context.requestTime"
        sourceIp        = "$context.identity.sourceIp"
        vpceId          = "$context.identity.vpceId"
        httpMethod      = "$context.httpMethod"
        resourcePath    = "$context.resourcePath"
        status          = "$context.status"
        responseLatency = "$context.responseLatency"
        # --- authentication layer ---
        principalId     = "$context.authorizer.principalId"
        subject         = "$context.authorizer.claims.sub"
        username        = "$context.authorizer.claims.email"
        tokenScope      = "$context.authorizer.claims.scope"
        tokenUse        = "$context.authorizer.claims.token_use"
        authorizerError = "$context.authorizer.error"
      })
    }
  }

  tags = var.extra_tags
}
