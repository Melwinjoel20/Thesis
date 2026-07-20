# =============================================================================
# Use Case: Networking — Dev Values
# Run: terraform apply (no -var-file needed, this file is auto-loaded)
# =============================================================================

PRODUCT      = "hotelbook"
ENVIRONMENT  = "dev"
REGION       = "us-east-1"
REGION_SHORT = "ue1"

# =============================================================================
# Hub VPC  —  10.0.0.0/16
# =============================================================================
HUB_VPC = {
  name_prefix = "hub"
  name_suffix = "001"
  vpc_cidr    = "10.0.0.0/16"

  subnets = {
    "tgw-subnet-a" = {
      cidr_block        = "10.0.2.0/28"
      availability_zone = "us-east-1a"
      type              = "private"
    }
    "hub-subnet-a" = {
      cidr_block        = "10.0.1.0/24"
      availability_zone = "us-east-1a"
      type              = "private"
    }
  }

  route_tables = {
    "private-rt" = { route_to_igw = false }
  }

  route_table_associations = {
    "tgw-subnet-a-assoc"     = { subnet_key = "tgw-subnet-a",     route_table_key = "private-rt" }
    "private-subnet-a-assoc" = { subnet_key = "hub-subnet-a", route_table_key = "private-rt" }
  }
}
# =============================================================================
# Frontend Spoke VPC  —  10.1.0.0/16
# =============================================================================
FRONTEND_VPC = {
  name_prefix = "fe"
  name_suffix = "001"
  vpc_cidr    = "10.1.0.0/16"

  subnets = {
    "private-subnet-a" = {
      cidr_block        = "10.1.1.0/24"
      availability_zone = "us-east-1a"
      type              = "private"
    }
    # Second AZ: an internal ALB (required for EB in a private VPC —
    # SingleInstance always demands an EIP/IGW) needs two subnets.
    "private-subnet-b" = {
      cidr_block        = "10.1.2.0/24"
      availability_zone = "us-east-1b"
      type              = "private"
    }
  }

  route_tables = {
    "private-rt" = { route_to_igw = false }
  }

  route_table_associations = {
    "private-subnet-a-assoc" = { subnet_key = "private-subnet-a", route_table_key = "private-rt" }
    "private-subnet-b-assoc" = { subnet_key = "private-subnet-b", route_table_key = "private-rt" }
  }
}

# =============================================================================
# App Spoke VPC  —  10.2.0.0/16
# =============================================================================
APP_VPC = {
  name_prefix = "app"
  name_suffix = "001"
  vpc_cidr    = "10.2.0.0/16"

  subnets = {
    "private-subnet-a" = {
      cidr_block        = "10.2.1.0/24"
      availability_zone = "us-east-1a"
      type              = "private"
    }
  }

  route_tables = {
    "private-rt" = { route_to_igw = false }
  }

  route_table_associations = {
    "private-subnet-a-assoc" = { subnet_key = "private-subnet-a", route_table_key = "private-rt" }
  }
}

# =============================================================================
# Database Spoke VPC  —  10.3.0.0/16
# =============================================================================
DATABASE_VPC = {
  name_prefix = "db"
  name_suffix = "001"
  vpc_cidr    = "10.3.0.0/16"

  subnets = {
    "private-subnet-a" = {
      cidr_block        = "10.3.1.0/24"
      availability_zone = "us-east-1a"
      type              = "private"
    }
  }

  route_tables = {
    "private-rt" = { route_to_igw = false }
  }

  route_table_associations = {
    "private-subnet-a-assoc" = { subnet_key = "private-subnet-a", route_table_key = "private-rt" }
  }
}

# =============================================================================
# Transit Gateway
# =============================================================================
TGW_NAME_PREFIX = "hub"
TGW_NAME_SUFFIX = "001"

# Point-to-site VPN for accessing the app on its real domain (cost-bearing).
ENABLE_CLIENT_VPN = true
