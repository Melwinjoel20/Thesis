output "flow_log_bucket" {
  description = "S3 bucket holding VPC Flow Logs (per-VPC key prefixes)."
  value       = aws_s3_bucket.flow.bucket
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
