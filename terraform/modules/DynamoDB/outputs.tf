# =============================================================================
# Module: DynamoDB — Outputs
# =============================================================================

output "table_names" {
  description = "Map of table keys to their names."
  value       = { for k, v in aws_dynamodb_table.this : k => v.name }
}

output "table_arns" {
  description = "Map of table keys to their ARNs."
  value       = { for k, v in aws_dynamodb_table.this : k => v.arn }
}
