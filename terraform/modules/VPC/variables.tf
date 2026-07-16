# =============================================================================
# Module: VPC — Variables
# =============================================================================

variable "product" {
  type        = string
  description = "The product name. Used in resource naming."
}

variable "environment" {
  type        = string
  description = "The environment name (e.g. dev, staging, prod)."
}

variable "region_short" {
  type        = string
  description = "Short form of the AWS region (e.g. ue1 for us-east-1)."
}

variable "name_prefix" {
  type        = string
  description = "Prefix for the VPC and all child resources."
}

variable "name_suffix" {
  type        = string
  description = "Suffix for the VPC and all child resources."
  default     = "001"
}

variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC."
}

variable "enable_igw" {
  type        = bool
  description = "Whether to create an Internet Gateway. Set true for Hub VPC only."
  default     = false
}

variable "subnets" {
  description = "Map of subnets to create inside the VPC."
  type = map(object({
    cidr_block              = string
    availability_zone       = string
    map_public_ip_on_launch = optional(bool, false)
    type                    = optional(string, "private")
  }))
  default = {}
}

variable "route_tables" {
  description = "Map of route tables to create. Set route_to_igw = true for public tables."
  type = map(object({
    route_to_igw = optional(bool, false)
  }))
  default = {}
}

variable "route_table_associations" {
  description = "Map of subnet-to-route-table associations."
  type = map(object({
    subnet_key      = string
    route_table_key = string
  }))
  default = {}
}

variable "extra_tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources."
  default     = {}
}
