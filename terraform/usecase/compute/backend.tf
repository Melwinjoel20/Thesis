
terraform {
  backend "s3" {
    key = "easycart/compute.tfstate"
  }
}
