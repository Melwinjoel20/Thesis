# =============================================================================
# Module: InterfaceEndpoints
# Description: Generic Interface VPC endpoints + a shared security group.
#              Reusable for any AWS service (execute-api, sns, cognito-idp...).
# =============================================================================

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-sg-vpce-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  description = "HTTPS to interface endpoints in ${var.name_prefix}"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from allowed CIDRs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.extra_tags, {
    Name = "${var.name_prefix}-sg-vpce-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  })
}

resource "aws_vpc_endpoint" "this" {
  for_each = toset(var.service_names)

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.this.id]
  private_dns_enabled = var.private_dns_enabled

  tags = merge(var.extra_tags, {
    Name = "${var.name_prefix}-vpce-${each.value}-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  })
}
