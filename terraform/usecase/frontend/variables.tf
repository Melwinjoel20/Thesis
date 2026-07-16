variable "PRODUCT" { type = string }
variable "ENVIRONMENT" { type = string }
variable "REGION" { type = string }
variable "REGION_SHORT" { type = string }

variable "ALLOWED_INGRESS_CIDRS" {
  type        = list(string)
  description = "CIDRs allowed to reach the EB instances (Hub + App spokes)."
  default     = ["10.0.0.0/16", "10.2.0.0/16"]
}

variable "EB_SOLUTION_STACK" {
  type        = string
  description = "EB platform name. List current ones with: aws elasticbeanstalk list-available-solution-stacks"
  default     = "64bit Amazon Linux 2023 v4.3.1 running Python 3.11"
}

variable "EB_SERVICE_ROLE" {
  type    = string
  default = "LabRole"
}

variable "EB_INSTANCE_PROFILE" {
  type    = string
  default = "LabInstanceProfile"
}

variable "STATE_BUCKET" {
  type        = string
  description = "S3 bucket holding Terraform state — must match backend.hcl."
}
