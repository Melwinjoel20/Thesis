# =============================================================================
# Use Case: Frontend — Dev Values
# VPC / subnet IDs are read from ../networking state automatically.
# =============================================================================

PRODUCT      = "easycart"
ENVIRONMENT  = "dev"
REGION       = "us-east-1"
REGION_SHORT = "ue1"

# Only the zero-trust matrix allows these to reach the frontend:
ALLOWED_INGRESS_CIDRS = ["10.0.0.0/16", "10.2.0.0/16"] # hub, app

# Solution stack names rotate — verify before apply:
#   aws elasticbeanstalk list-available-solution-stacks | grep "Python 3.11"
EB_SOLUTION_STACK   = "64bit Amazon Linux 2023 v4.3.1 running Python 3.11"
EB_SERVICE_ROLE     = "LabRole"
EB_INSTANCE_PROFILE = "LabInstanceProfile"

# Must match the bucket in infra/backend.hcl
STATE_BUCKET = "easycart-tfstate-mel4821"
