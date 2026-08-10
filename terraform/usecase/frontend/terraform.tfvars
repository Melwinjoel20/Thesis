
# Use Case: Frontend — Dev Values



PRODUCT      = "easycart"
ENVIRONMENT  = "dev"
REGION       = "us-east-1"
REGION_SHORT = "ue1"


ALLOWED_INGRESS_CIDRS = ["10.0.0.0/16", "10.2.0.0/16", "10.1.0.0/16"] # hub, app, frontend VPC itself (internal ALB -> instances + health checks)



EB_SOLUTION_STACK   = "64bit Amazon Linux 2023 v4.3.1 running Python 3.11"
EB_SERVICE_ROLE     = "LabRole"
EB_INSTANCE_PROFILE = "LabInstanceProfile"

# Must match the bucket in infra/backend.hcl
STATE_BUCKET = "easycart-tfstate-mel4821"
