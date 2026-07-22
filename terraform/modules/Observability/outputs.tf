output "flow_log_group_names" {
  description = "Per-VPC flow log group names."
  value       = { for k, v in aws_cloudwatch_log_group.flow : k => v.name }
}

output "vpn_log_group_name" {
  value = aws_cloudwatch_log_group.vpn.name
}

output "vpn_log_stream_name" {
  value = aws_cloudwatch_log_stream.vpn.name
}

output "api_log_group_name" {
  value = aws_cloudwatch_log_group.api.name
}

output "api_log_group_arn" {
  value = aws_cloudwatch_log_group.api.arn
}

output "app_log_group_name" {
  value = aws_cloudwatch_log_group.app.name
}
