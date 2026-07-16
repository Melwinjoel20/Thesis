# =============================================================================
# Use Case: Database — Dev Values
# VPC / route table IDs are read from ../networking state automatically.
# Table definitions live in main.tf.
# =============================================================================

PRODUCT      = "easycart"
ENVIRONMENT  = "dev"
REGION       = "us-east-1"
REGION_SHORT = "ue1"

# Must match the bucket in infra/backend.hcl
STATE_BUCKET = "easycart-tfstate-mel4821"
