# Backend: S3 remote state so local runs and the GitHub Actions pipeline share
# one source of truth. Bucket + region come from ../../backend.hcl:
#   terraform init -backend-config=../../backend.hcl
terraform {
  backend "s3" {
    key = "easycart/networking.tfstate"
  }
}
