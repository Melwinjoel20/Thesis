# =============================================================================
# Module: SSMEndpoints — Outputs
# =============================================================================

output "endpoint_security_group_id" {
  description = "Security group ID guarding the interface endpoints."
  value       = aws_security_group.endpoints.id
}

output "endpoint_ids" {
  description = "Map of service name to endpoint ID."
  value       = { for k, v in aws_vpc_endpoint.ssm : k => v.id }
}
