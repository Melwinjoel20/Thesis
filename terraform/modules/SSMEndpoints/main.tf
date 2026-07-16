# =============================================================================
# Module: SSMEndpoints
# Description: Creates the three VPC interface endpoints required for AWS
#              Systems Manager Session Manager to work on FULLY PRIVATE
#              instances (no IGW, no NAT, no public IP):
#                - ssm           (registration + commands)
#                - ssmmessages   (the live Session Manager channel)
#                - ec2messages   (legacy agent messaging)
#
#              Also creates the security group that guards these endpoints.
#              This is the Terraform equivalent of "Step 8" from the manual
#              build — without it, the SSM agent's outbound 443 call to
#              ssm.<region>.amazonaws.com has nowhere to go and the
#              instance never registers (Ping status: Offline).
# =============================================================================

# -----------------------------------------------------------------------------
# Security group for the interface endpoints.
# Allows inbound HTTPS (443) only from inside the VPC — i.e. from the
# instances that need to reach the SSM service. Egress open so the
# endpoint ENI can respond.
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# The three interface endpoints. Service name is built from the region, so
# this module is region-agnostic — change REGION in tfvars and these adjust
# automatically (com.amazonaws.<region>.ssm, etc.).
# private_dns_enabled = true is what hijacks ssm.<region>.amazonaws.com
# inside the VPC so the agent reaches the endpoint instead of the internet.
# -----------------------------------------------------------------------------
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
