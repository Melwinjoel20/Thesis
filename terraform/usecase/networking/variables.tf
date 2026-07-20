# =============================================================================
# Use Case: Networking — Variables
# =============================================================================

variable "PRODUCT" {
  type        = string
  description = "The product name."
}

variable "ENVIRONMENT" {
  type        = string
  description = "The environment name (e.g. dev, staging, prod)."
}

variable "REGION" {
  type        = string
  description = "The AWS region to deploy into."
}

variable "REGION_SHORT" {
  type        = string
  description = "Short form of the AWS region (e.g. ew1 for eu-west-1)."
}

# -----------------------------------------------------------------------------
# Compute / SSM knobs
# -----------------------------------------------------------------------------
variable "INSTANCE_TYPE" {
  type        = string
  description = "EC2 instance type for the test instances."
  default     = "t3.micro"
}

variable "INSTANCE_PROFILE" {
  type        = string
  description = "IAM instance profile NAME. In AWS Academy Learner Lab use 'LabInstanceProfile'."
  default     = "LabInstanceProfile"
}

variable "PING_CIDRS" {
  type        = list(string)
  description = "CIDRs allowed to ping the test instances. Default = all private space."
  default     = ["10.0.0.0/8"]
}

# -----------------------------------------------------------------------------
# VPC object type — shared shape for hub + all spokes
# -----------------------------------------------------------------------------
variable "HUB_VPC" {
  description = "Hub VPC configuration."
  type = object({
    name_prefix = string
    name_suffix = string
    vpc_cidr    = string
    subnets = map(object({
      cidr_block              = string
      availability_zone       = string
      map_public_ip_on_launch = optional(bool, false)
      type                    = optional(string, "private")
    }))
    route_tables = map(object({
      route_to_igw = optional(bool, false)
    }))
    route_table_associations = map(object({
      subnet_key      = string
      route_table_key = string
    }))
  })
}

variable "FRONTEND_VPC" {
  description = "Frontend Spoke VPC configuration."
  type = object({
    name_prefix = string
    name_suffix = string
    vpc_cidr    = string
    subnets = map(object({
      cidr_block              = string
      availability_zone       = string
      map_public_ip_on_launch = optional(bool, false)
      type                    = optional(string, "private")
    }))
    route_tables = map(object({
      route_to_igw = optional(bool, false)
    }))
    route_table_associations = map(object({
      subnet_key      = string
      route_table_key = string
    }))
  })
}

variable "APP_VPC" {
  description = "Application Spoke VPC configuration."
  type = object({
    name_prefix = string
    name_suffix = string
    vpc_cidr    = string
    subnets = map(object({
      cidr_block              = string
      availability_zone       = string
      map_public_ip_on_launch = optional(bool, false)
      type                    = optional(string, "private")
    }))
    route_tables = map(object({
      route_to_igw = optional(bool, false)
    }))
    route_table_associations = map(object({
      subnet_key      = string
      route_table_key = string
    }))
  })
}

variable "DATABASE_VPC" {
  description = "Database Spoke VPC configuration."
  type = object({
    name_prefix = string
    name_suffix = string
    vpc_cidr    = string
    subnets = map(object({
      cidr_block              = string
      availability_zone       = string
      map_public_ip_on_launch = optional(bool, false)
      type                    = optional(string, "private")
    }))
    route_tables = map(object({
      route_to_igw = optional(bool, false)
    }))
    route_table_associations = map(object({
      subnet_key      = string
      route_table_key = string
    }))
  })
}

variable "TGW_NAME_PREFIX" {
  type    = string
  default = "hub"
}

variable "TGW_NAME_SUFFIX" {
  type    = string
  default = "001"
}

variable "ENABLE_CLIENT_VPN" {
  type        = bool
  default     = false
  description = "Deploy the point-to-site Client VPN (cost-bearing; enable for demos)."
}
