# =============================================================================
# Module: Compute — Variables
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
  description = "Prefix for naming the instance and its SG."
}

variable "name_suffix" {
  type        = string
  description = "Suffix for naming."
  default     = "001"
}

variable "vpc_id" {
  type        = string
  description = "VPC the instance and SG live in."
}

variable "subnet_id" {
  type        = string
  description = "Subnet to launch the instance in (private, no public IP)."
}

variable "ami" {
  type        = string
  description = "AMI ID. Pass the Amazon Linux 2023 AMI (resolved at the root)."
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type."
  default     = "t3.micro"
}

variable "instance_profile" {
  type        = string
  description = "IAM instance profile NAME. In Learner Lab this is 'LabInstanceProfile'."
}

variable "icmp_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to ping this instance."
  default     = ["10.0.0.0/8"]
}

variable "extra_tags" {
  type        = map(string)
  description = "Additional tags."
  default     = {}
}
