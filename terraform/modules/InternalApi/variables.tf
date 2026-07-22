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

variable "user_pool_arn" {
  type        = string
  description = "Cognito user pool ARN backing the JWT authorizer."
}

variable "functions" {
  description = "Routes to expose: map of route path -> { function_name, invoke_arn }."
  type = map(object({
    function_name = string
    invoke_arn    = string
  }))
}

variable "vpc_endpoint_id" {
  type        = string
  description = "execute-api Interface endpoint (from the networking layer) — the ONLY allowed entry."
}

variable "stage_name" {
  type    = string
  default = "internal"
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}

variable "access_log_group_arn" {
  type        = string
  description = "CloudWatch log group ARN for identity-attributed access logs. Empty disables."
  default     = ""
}
