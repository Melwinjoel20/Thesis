# =============================================================================
# Module: ElasticBeanstalk — Variables
# =============================================================================

variable "product" {
  type = string
}

variable "environment" {
  type = string
}

variable "region_short" {
  type = string
}

variable "name_prefix" {
  type    = string
  default = "fe"
}

variable "name_suffix" {
  type    = string
  default = "001"
}

variable "solution_stack_name" {
  type        = string
  description = "EB platform. E.g. '64bit Amazon Linux 2023 v4.x.x running Python 3.11'"
}

variable "environment_type" {
  type        = string
  description = "SingleInstance or LoadBalanced."
  default     = "SingleInstance"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for EB environment."
  default     = "t3.micro"
}

variable "service_role" {
  type        = string
  description = "IAM service role for Elastic Beanstalk."
  default     = "LabRole"
}

variable "instance_profile" {
  type        = string
  description = "IAM instance profile for EC2 instances."
  default     = "LabInstanceProfile"
}

# Networking — Frontend Spoke VPC
variable "vpc_id" {
  type        = string
  description = "Frontend Spoke VPC ID."
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs inside the Frontend Spoke VPC."
}

variable "security_group_id" {
  type        = string
  description = "Security group ID for the EB instances. Should only allow traffic from Hub VPC CIDR."
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}
