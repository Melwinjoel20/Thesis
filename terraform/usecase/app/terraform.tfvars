# =============================================================================
# Use Case: App — Dev Values
# VPC / subnet IDs are read from ../networking state automatically.
# The Lambda role is looked up by name — no account ID needed.
# =============================================================================

PRODUCT      = "easycart"
ENVIRONMENT  = "dev"
REGION       = "us-east-1"
REGION_SHORT = "ue1"

LAMBDA_ROLE_NAME = "LabRole"

# Set to receive order-placed emails (confirm the SNS subscription email!).
# Leave "" to skip.
ORDER_NOTIFICATION_EMAIL = ""

# Where the built Lambda zips live. Default is the lambda/ folder inside this
# repo. If your app code lives in a separate repo, point here instead, e.g.:
#   LAMBDA_ZIP_DIR = "../../../easycart-app/dist"      (relative to this dir)
#   LAMBDA_ZIP_DIR = "/Users/you/code/easycart-app/dist"
LAMBDA_ZIP_DIR = "../../../infra/lambda" # the app repo's real Lambda code (repo root/infra/lambda)

# Must match the bucket in infra/backend.hcl
STATE_BUCKET = "easycart-tfstate-mel4821"
