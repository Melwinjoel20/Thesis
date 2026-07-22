variable "product" { type = string }
variable "environment" { type = string }
variable "region" { type = string }
variable "region_short" { type = string }

variable "name_prefix" {
  type    = string
  default = "obs"
}

variable "name_suffix" {
  type    = string
  default = "001"
}

variable "vpc_ids" {
  type        = map(string)
  description = "VPCs to enable Flow Logs on, keyed by role (hub, frontend, app, database)."
}

variable "flow_log_role_arn" {
  type        = string
  description = "Role assumed by the VPC Flow Logs service to write to CloudWatch (Learner Lab: LabRole)."
}

variable "log_retention_days" {
  type        = number
  default     = 30
  description = "CloudWatch retention. Short values keep lab costs down."
}

variable "flow_log_traffic_type" {
  type        = string
  default     = "ALL"
  description = "ACCEPT, REJECT or ALL. REJECT alone evidences blocked lateral movement; ALL is needed for traceability metrics."
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}
