
terraform {
  backend "s3" {
    key = "easycart/networking.tfstate"
  }
}
