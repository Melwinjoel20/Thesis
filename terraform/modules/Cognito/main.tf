
resource "aws_cognito_user_pool" "this" {
  name = "${var.name_prefix}-userpool-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"

  user_pool_tier = "LITE" # Essentials (default) carries Managed Login, which blocks PrivateLink

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_message        = "Welcome to EasyCart! Your verification code is: {####}. If you didn't request this, ignore this email."
    email_subject        = "EasyCart Email Verification"
  }

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
  }

  tags = var.extra_tags
}


resource "aws_cognito_user_pool_client" "this" {
  name         = "${var.name_prefix}-appclient-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret = true

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  allowed_oauth_flows_user_pool_client = false
  allowed_oauth_flows                  = []
  allowed_oauth_scopes                 = []

  prevent_user_existence_errors = "ENABLED"
}



