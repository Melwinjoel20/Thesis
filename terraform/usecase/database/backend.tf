
terraform {
  backend "s3" {
    key = "easycart/database.tfstate"
  }
}
