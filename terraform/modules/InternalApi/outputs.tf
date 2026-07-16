output "api_id" {
  value = aws_api_gateway_rest_api.this.id
}

output "base_url" {
  description = "Endpoint-specific invoke URL, reachable from internal VPCs."
  value       = "https://${aws_api_gateway_rest_api.this.id}-${var.vpc_endpoint_id}.execute-api.${var.region}.amazonaws.com/${var.stage_name}"
}
