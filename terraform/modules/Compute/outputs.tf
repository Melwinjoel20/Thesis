# =============================================================================
# Module: Compute — Outputs
# =============================================================================

output "instance_id" {
  description = "The EC2 instance ID."
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "The private IP of the instance — use this as the ping target."
  value       = aws_instance.this.private_ip
}

output "security_group_id" {
  description = "The instance security group ID."
  value       = aws_security_group.instance.id
}
