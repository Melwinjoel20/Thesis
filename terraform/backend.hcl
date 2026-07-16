# =============================================================================
# Shared S3 backend settings — used by every stack via:
#   terraform init -backend-config=../../backend.hcl
# The per-stack state KEY is set in each stack's backend.tf.
#
# 1. Create the bucket once (names are global — change CHANGEME):
#      aws s3 mb s3://easycart-tfstate-mel4821 --region us-east-1
#      aws s3api put-bucket-versioning --bucket easycart-tfstate-mel4821 \
#        --versioning-configuration Status=Enabled
# 2. Replace CHANGEME everywhere in one go:
#      grep -rl "easycart-tfstate-mel4821" . | xargs sed -i 's/easycart-tfstate-mel4821/<your-bucket>/'
# =============================================================================

bucket       = "easycart-tfstate-mel4821"
region       = "us-east-1"
use_lockfile = true # native S3 state locking — requires Terraform >= 1.10
