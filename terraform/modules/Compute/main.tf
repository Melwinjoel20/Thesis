
resource "aws_security_group" "instance" {
  name        = "${var.name_prefix}-ec2-sg-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  description = "Allow ICMP for ping tests; egress open for SSM agent"
  vpc_id      = var.vpc_id

  ingress {
    description = "All ICMP IPv4 (ping)"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = var.icmp_cidrs
  }

  egress {
    description = "All outbound (SSM agent needs 443 to endpoints)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.extra_tags, {
    Name = "${var.name_prefix}-ec2-sg-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  })
}

# -----------------------------------------------------------------------------
# The instance itself.
# -----------------------------------------------------------------------------
resource "aws_instance" "this" {
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.instance.id]
  iam_instance_profile        = var.instance_profile
  associate_public_ip_address = false

  metadata_options {
    http_tokens   = "required" 
    http_endpoint = "enabled"
  }

  tags = merge(var.extra_tags, {
    Name = "${var.name_prefix}-ec2-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  })
}
