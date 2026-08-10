
terraform {
  backend "s3" {
    key = "easycart/frontend.tfstate"
  }
}
