# =============================================================================
# Module: VPC
# Description: Creates a VPC with subnets, route tables, and optional
#              Internet Gateway. Designed for hub-and-spoke topology on AWS.
#              Follows the same dynamic patterns as the Azure Networking module.
# =============================================================================

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.extra_tags, {
    Name = "${var.name_prefix}-vpc-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  })
}

# -----------------------------------------------------------------------------
# Internet Gateway (only created if enable_igw = true — used for Hub VPC)
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "this" {
  count  = var.enable_igw ? 1 : 0
  vpc_id = aws_vpc.this.id

  tags = merge(var.extra_tags, {
    Name = "${var.name_prefix}-igw-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  })
}

# -----------------------------------------------------------------------------
# Subnets — created dynamically from the subnets map variable
# -----------------------------------------------------------------------------
resource "aws_subnet" "this" {
  for_each = var.subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = lookup(each.value, "map_public_ip_on_launch", false)

  tags = merge(var.extra_tags, {
    Name = "${var.name_prefix}-snet-${each.key}-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
    Type = lookup(each.value, "type", "private")
  })
}

# -----------------------------------------------------------------------------
# Route Tables — one per subnet group (public / private)
# -----------------------------------------------------------------------------
resource "aws_route_table" "this" {
  for_each = var.route_tables

  vpc_id = aws_vpc.this.id

  tags = merge(var.extra_tags, {
    Name = "${var.name_prefix}-rt-${each.key}-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  })
}

# Default route to Internet Gateway for public route tables
resource "aws_route" "igw" {
  for_each = {
    for k, v in var.route_tables : k => v
    if v.route_to_igw == true && var.enable_igw
  }

  route_table_id         = aws_route_table.this[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

# -----------------------------------------------------------------------------
# Route Table Associations — map subnets to route tables
# -----------------------------------------------------------------------------
resource "aws_route_table_association" "this" {
  for_each = var.route_table_associations

  subnet_id      = aws_subnet.this[each.value.subnet_key].id
  route_table_id = aws_route_table.this[each.value.route_table_key].id
}
