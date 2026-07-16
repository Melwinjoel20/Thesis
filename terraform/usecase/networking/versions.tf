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

# -----------------------------------------------------------------------------
# Latest Amazon Linux 2023 AMI, resolved from the public SSM parameter.
# Region-agnostic: returns the correct AMI for whatever REGION is set.
# AL2023 ships with the SSM agent pre-installed, so no user_data is needed.
# -----------------------------------------------------------------------------
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

