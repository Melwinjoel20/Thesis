variable "product" { type = string }
variable "environment" { type = string }
variable "region" { type = string }
variable "region_short" { type = string }

variable "name_prefix" {
  type        = string
  description = "VPC short name for resource naming (hub, fe, app, db)."
}

variable "name_suffix" {
  type    = string
  default = "001"
}

variable "vpc_id" { type = string }

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets to place the endpoint ENIs in (one AZ is usually enough)."
}

variable "service_names" {
  type        = list(string)
  description = "Interface endpoint services, short names (e.g. [\"execute-api\", \"sns\"])."
}

variable "allowed_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the endpoints over HTTPS."
}

variable "private_dns_enabled" {
  type    = bool
  default = true
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}
