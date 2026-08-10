
terraform {
  backend "s3" {
    key = "easycart/storage.tfstate"
  }
}
