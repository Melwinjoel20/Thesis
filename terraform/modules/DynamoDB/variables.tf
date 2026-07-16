# =============================================================================
# Module: DynamoDB — Variables
# =============================================================================

variable "product" {
  type        = string
  description = "Product name used in resource naming."
}

variable "environment" {
  type        = string
  description = "Environment name (e.g. dev, prod)."
}

variable "region" {
  type        = string
  description = "AWS region (e.g. us-east-1)."
}

variable "region_short" {
  type        = string
  description = "Short form of the AWS region (e.g. ue1)."
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource naming."
  default     = "db"
}

variable "name_suffix" {
  type        = string
  description = "Suffix for resource naming."
  default     = "001"
}

variable "tables" {
  description = "Map of DynamoDB tables to create. Key is the table name."
  type = map(object({
    hash_key       = string
    hash_key_type  = string
    range_key      = optional(string)
    range_key_type = optional(string)
    additional_attributes = optional(list(object({
      name = string
      type = string
    })), [])
  }))
}

variable "vpc_id" {
  type        = string
  description = "VPC ID — passed in from use case, used for reference."
}

variable "route_table_ids" {
  type        = list(string)
  description = "Route table IDs — passed in from use case, used for reference."
}

variable "extra_tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources."
  default     = {}
}
