variable "product" { type = string }
variable "environment" { type = string }
variable "region" { type = string }
variable "region_short" { type = string }
variable "name_prefix" {
  type    = string
  default = "app"
}
variable "name_suffix" {
  type    = string
  default = "001"
}

variable "lambda_role_arn" {
  type        = string
  description = "IAM role ARN for all Lambda functions."
}

variable "functions" {
  description = "Map of Lambda functions to create. Key is the function short name."
  type = map(object({
    zip_path = string
    env_vars = optional(map(string), {})
  }))
}

# Networking — App Spoke VPC
variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs inside the App Spoke VPC."
}

variable "security_group_id" {
  type        = string
  description = "Security group for Lambda functions — only allow traffic from Frontend Spoke CIDR."
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}
