
# -----------------------------------------------------------------------------
# Transit Gateway
# -----------------------------------------------------------------------------
resource "aws_ec2_transit_gateway" "this" {
  description                     = "Transit Gateway for ${var.product}-${var.environment} hub-and-spoke"
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

  tags = merge(var.extra_tags, {
    Name = "${var.name_prefix}-tgw-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  })
}

# -----------------------------------------------------------------------------
# Transit Gateway VPC Attachments — one per VPC passed in
# -----------------------------------------------------------------------------
resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  for_each = var.vpc_attachments

  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = each.value.vpc_id
  subnet_ids         = each.value.subnet_ids

  tags = merge(var.extra_tags, {
    Name = "${var.name_prefix}-tgw-att-${each.key}-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  })
}

# -----------------------------------------------------------------------------
# Routes in each Spoke VPC pointing back to the Transit Gateway
# This allows Spoke to Hub and Spoke to Spoke traffic via the TGW
# -----------------------------------------------------------------------------
resource "aws_route" "tgw_routes" {
  for_each = var.tgw_routes

  route_table_id         = each.value.route_table_id
  destination_cidr_block = each.value.destination_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}
