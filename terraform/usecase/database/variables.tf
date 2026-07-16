variable "PRODUCT" { type = string }
variable "ENVIRONMENT" { type = string }
variable "REGION" { type = string }
variable "REGION_SHORT" { type = string }

variable "STATE_BUCKET" {
  type        = string
  description = "S3 bucket holding Terraform state — must match backend.hcl."
}
