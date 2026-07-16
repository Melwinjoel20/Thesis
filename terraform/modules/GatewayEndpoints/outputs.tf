output "endpoint_ids" {
  description = "Map of service name to endpoint ID."
  value       = { for k, v in aws_vpc_endpoint.this : k => v.id }
}

output "endpoint_states" {
  description = "Map of service name to endpoint state."
  value       = { for k, v in aws_vpc_endpoint.this : k => v.state }
}