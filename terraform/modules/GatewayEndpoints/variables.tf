# =============================================================================
# Module: DynamoDBEndpoint — Variables
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
  description = "AWS region (e.g. us-east-1). Used to build the service name."
}

variable "region_short" {
  type        = string
  description = "Short form of the AWS region (e.g. ue1)."
}

variable "name_prefix" {
  type        = string
  description = "Prefix for the endpoint name — use the VPC name e.g. hub, db, app."
}

variable "name_suffix" {
  type        = string
  description = "Suffix for the endpoint name."
  default     = "001"
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC to create the endpoint in."
}

variable "route_table_ids" {
  type        = list(string)
  description = "List of route table IDs to associate the endpoint with. AWS will add a route automatically."
}

variable "extra_tags" {
  type        = map(string)
  description = "Additional tags to apply to the endpoint."
  default     = {}
}

variable "service_names" {
  type        = list(string)
  description = "List of Gateway endpoint services to create."
  default     = ["dynamodb"]
}