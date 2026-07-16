variable "product" { type = string }
variable "environment" { type = string }
variable "region_short" { type = string }
variable "name_prefix" {
  type    = string
  default = "app"
}
variable "name_suffix" {
  type    = string
  default = "001"
}
variable "extra_tags" {
  type    = map(string)
  default = {}
}
