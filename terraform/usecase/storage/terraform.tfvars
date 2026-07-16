# =============================================================================
# Use Case: Storage — Dev Values
# VPC / route table IDs are read from ../networking state automatically.
# =============================================================================

PRODUCT      = "easycart"
ENVIRONMENT  = "dev"
REGION       = "us-east-1"
REGION_SHORT = "ue1"

# S3 bucket names are globally unique — change the suffix if apply fails.
S3_BUCKET_NAME = "easycart-private-dev-ue1-001"

# Must match the bucket in infra/backend.hcl
STATE_BUCKET = "easycart-tfstate-mel4821"
