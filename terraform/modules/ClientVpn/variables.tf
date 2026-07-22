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

variable "vpc_id" { type = string }

variable "association_subnet_id" {
  type        = string
  description = "Subnet whose ENI carries VPN traffic into the network (hub)."
}

variable "client_cidr" {
  type        = string
  default     = "172.16.0.0/22"
  description = "CIDR handed to VPN clients. Must not overlap any VPC."
}

variable "spoke_cidrs" {
  type        = list(string)
  description = "Spoke VPC CIDRs reachable through the VPN (via hub + TGW)."
}

variable "vpc_dns_resolver" {
  type        = string
  description = "VPC .2 resolver IP so clients resolve like an internal host (e.g. 10.0.0.2)."
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}

variable "connection_log_group" {
  type        = string
  description = "CloudWatch log group for VPN connection (translation) logs. Empty disables logging."
  default     = ""
}

variable "connection_log_stream" {
  type        = string
  description = "CloudWatch log stream for VPN connection logs."
  default     = ""
}
