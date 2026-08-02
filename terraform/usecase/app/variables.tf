variable "PRODUCT" { type = string }
variable "ENVIRONMENT" { type = string }
variable "REGION" { type = string }
variable "REGION_SHORT" { type = string }

variable "LAMBDA_ROLE_NAME" {
  type        = string
  description = "Name of the pre-existing Lambda execution role (Learner Lab: LabRole)."
  default     = "LabRole"
}

variable "ORDER_NOTIFICATION_EMAIL" {
  type        = string
  description = "Optional email for SNS order notifications. Empty = no subscription."
  default     = ""
}

variable "LAMBDA_ZIP_DIR" {
  type        = string
  description = "Directory containing the built Lambda zips. Relative paths resolve from this stack directory. Point this at your application repo's build output."
  default     = "../../../infra/lambda"
}

variable "STATE_BUCKET" {
  type        = string
  description = "S3 bucket holding Terraform state — must match backend.hcl."
}
