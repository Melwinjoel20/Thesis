
# Module: SSMEndpoints


resource "aws_security_group" "endpoints" {
  name        = "${var.name_prefix}-ep-sg-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  description = "Allow HTTPS to SSM interface endpoints from within the VPC"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from VPC for SSM endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.extra_tags, {
    Name = "${var.name_prefix}-ep-sg-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  })
}


resource "aws_vpc_endpoint" "ssm" {
  for_each = toset(var.service_names)

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = merge(var.extra_tags, {
    Name = "${var.name_prefix}-${each.value}-ep-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  })
}
