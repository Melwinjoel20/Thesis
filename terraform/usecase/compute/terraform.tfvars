

PRODUCT      = "hotelbook"
ENVIRONMENT  = "dev"
REGION       = "us-east-1"
REGION_SHORT = "ue1"

# Learner Lab pre-made instance profile — do not change
INSTANCE_PROFILE = "LabInstanceProfile"
INSTANCE_TYPE    = "t3.micro"

# Allow ping from anywhere in RFC-1918 private space.
# TGW route table is the real enforcement layer — this just keeps the SG
# from being the silent blocker (the lesson from the manual build).
PING_CIDRS = ["10.0.0.0/8"]

# Must match the bucket in infra/backend.hcl
STATE_BUCKET = "easycart-tfstate-mel4821"
