# =============================================================================
# Module: SSMEndpoints — Variables
# =============================================================================

variable "product" {
  type        = string
  description = "The product name."
}

variable "environment" {
  type        = string
  description = "The environment name."
}

variable "region" {
  type        = string
  description = "Full AWS region (e.g. eu-west-1). Used to build endpoint service names."
}

variable "region_short" {
  type        = string
  description = "Short form of the AWS region (e.g. ew1)."
}

variable "name_prefix" {
  type        = string
  description = "Prefix for naming the endpoints and their security group."
}

variable "name_suffix" {
  type        = string
  description = "Suffix for naming."
  default     = "001"
}

variable "vpc_id" {
  type        = string
  description = "The VPC the endpoints live in."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs to place the endpoint ENIs in (usually the private/instance subnet)."
}

variable "allowed_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the endpoints on 443. Normally just the VPC CIDR."
}

variable "service_names" {
  type        = list(string)
  description = "Short SSM service names to create interface endpoints for."
  default     = ["ssm", "ssmmessages", "ec2messages"]
}

variable "extra_tags" {
  type        = map(string)
  description = "Additional tags."
  default     = {}
}
