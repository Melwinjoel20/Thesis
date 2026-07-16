# =============================================================================
# Use Case: Compute — Variables
# =============================================================================

variable "PRODUCT" {
  type        = string
  description = "The product name."
}

variable "ENVIRONMENT" {
  type        = string
  description = "The environment name."
}

variable "REGION" {
  type        = string
  description = "AWS region to deploy into."
}

variable "REGION_SHORT" {
  type        = string
  description = "Short form of the AWS region (e.g. ue1 for us-east-1)."
}

variable "INSTANCE_TYPE" {
  type        = string
  description = "EC2 instance type."
  default     = "t3.micro"
}

variable "INSTANCE_PROFILE" {
  type        = string
  description = "IAM instance profile name. In Learner Lab use 'LabInstanceProfile'."
  default     = "LabInstanceProfile"
}

variable "PING_CIDRS" {
  type        = list(string)
  description = "CIDRs allowed to ping the instances. Default = all RFC-1918 private space."
  default     = ["10.0.0.0/8"]
}

variable "STATE_BUCKET" {
  type        = string
  description = "S3 bucket holding Terraform state — must match backend.hcl."
}
