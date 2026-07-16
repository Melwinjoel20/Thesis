# =============================================================================
# Module: TransitGateway — Variables
# =============================================================================

variable "product" {
  type        = string
  description = "The product name."
}

variable "environment" {
  type        = string
  description = "The environment name."
}

variable "region_short" {
  type        = string
  description = "Short form of the AWS region."
}

variable "name_prefix" {
  type        = string
  description = "Prefix for naming the Transit Gateway."
  default     = "hub"
}

variable "name_suffix" {
  type        = string
  description = "Suffix for naming the Transit Gateway."
  default     = "001"
}

variable "vpc_attachments" {
  description = "Map of VPCs to attach to the Transit Gateway. Key is the VPC name."
  type = map(object({
    vpc_id     = string
    subnet_ids = list(string)
  }))
}

variable "tgw_routes" {
  description = "Map of routes to add pointing to the Transit Gateway."
  type = map(object({
    route_table_id  = string
    destination_cidr = string
  }))
  default = {}
}

variable "extra_tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources."
  default     = {}
}
