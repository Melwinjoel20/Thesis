# =============================================================================
# Module: VPC — Outputs
# =============================================================================

output "vpc_id" {
  description = "The ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "subnet_ids" {
  description = "Map of subnet keys to their IDs."
  value       = { for k, v in aws_subnet.this : k => v.id }
}

output "subnet_cidrs" {
  description = "Map of subnet keys to their CIDR blocks."
  value       = { for k, v in aws_subnet.this : k => v.cidr_block }
}

output "route_table_ids" {
  description = "Map of route table keys to their IDs."
  value       = { for k, v in aws_route_table.this : k => v.id }
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway (if created)."
  value       = var.enable_igw ? aws_internet_gateway.this[0].id : null
}
