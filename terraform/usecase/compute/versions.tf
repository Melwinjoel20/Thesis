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


data "aws_caller_identity" "current" {}

data "terraform_remote_state" "networking" {
  backend = "s3"

  config = {
    bucket = "easycart-tfstate-${data.aws_caller_identity.current.account_id}"
    key    = "easycart/networking.tfstate"
    region = var.REGION
  }
}
