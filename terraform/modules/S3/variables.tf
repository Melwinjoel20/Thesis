variable "product" { type = string }
variable "environment" { type = string }
variable "region" { type = string }
variable "region_short" { type = string }
variable "name_prefix" {
  type    = string
  default = "hub"
}
variable "name_suffix" {
  type    = string
  default = "001"
}
variable "bucket_name" { type = string }

variable "vpc_id" {
  type        = string
  description = "Hub VPC ID for the S3 VPC Endpoint."
}

variable "route_table_ids" {
  type        = list(string)
  description = "Hub VPC route table IDs to associate the S3 VPC Endpoint with."
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}

variable "create_vpc_endpoint" {
  type        = bool
  description = "Create an S3 Gateway endpoint. Set false if the VPC already has one (a route table can only hold one S3 prefix-list route)."
  default     = true
}
