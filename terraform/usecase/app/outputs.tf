output "cognito_user_pool_id" { value = module.cognito.user_pool_id }
output "cognito_app_client_id" { value = module.cognito.app_client_id }
output "cognito_domain_url" { value = module.cognito.domain_url }
output "lambda_function_names" { value = module.lambda.function_names }
output "lambda_invoke_arns" { value = module.lambda.invoke_arns }
output "sns_topic_arn" { value = aws_sns_topic.orders.arn }
output "lambda_security_group_id" { value = aws_security_group.lambda.id }
output "cognito_app_client_secret" {
  value     = module.cognito.app_client_secret
  sensitive = true
}
