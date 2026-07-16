# =============================================================================
# Module: TransitGateway — Outputs
# =============================================================================

output "transit_gateway_id" {
  description = "The ID of the Transit Gateway."
  value       = aws_ec2_transit_gateway.this.id
}

output "attachment_ids" {
  description = "Map of VPC attachment keys to their IDs."
  value       = { for k, v in aws_ec2_transit_gateway_vpc_attachment.this : k => v.id }
}
