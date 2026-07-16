resource "aws_vpc_endpoint" "this" {
  for_each = toset(var.service_names)

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids

  tags = merge(var.extra_tags, {
    Name = "${var.name_prefix}-vpce-${each.value}-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  })
}