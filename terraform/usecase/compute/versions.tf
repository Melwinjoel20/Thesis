terraform {
  required_version = ">= 1.7.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
}

provider "aws" {
  region = var.REGION
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# -----------------------------------------------------------------------------
# Remote state — reads outputs from the networking use case so this layer
# knows which subnets and VPCs to place instances into without hardcoding IDs.
#
# HOW IT WORKS:
#   After `terraform apply` in usecase/networking/, Terraform writes a local
#   state file at usecase/networking/terraform.tfstate. This data source reads
#   that file and exposes every output from the networking layer as an
#   attribute here. State lives in the shared S3 backend (see ../../backend.hcl).
#
# IMPORTANT: run `terraform apply` in usecase/networking/ BEFORE applying this.
# -----------------------------------------------------------------------------
data "terraform_remote_state" "networking" {
  backend = "s3"

  config = {
    bucket = var.STATE_BUCKET
    key    = "easycart/networking.tfstate"
    region = var.REGION
  }
}
