# =============================================================================
# Module: S3
# Description: Creates a private S3 bucket for product images and logo.
#              No public access. Accessed via S3 VPC Endpoint from Hub VPC.
#              Replaces the public bucket from create_s3.py — Zero Trust
#              means no public S3 buckets.
# =============================================================================

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  force_destroy = true
  tags = merge(var.extra_tags, {
    Name = "${var.name_prefix}-s3-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  })
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# VPC Endpoint for S3 — optional: skip when the VPC already has one
# (e.g. networking's gateway_endpoints_hub creates s3 + dynamodb in the hub).
resource "aws_vpc_endpoint" "s3" {
  count = var.create_vpc_endpoint ? 1 : 0

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids

  tags = merge(var.extra_tags, {
    Name = "${var.name_prefix}-vpce-s3-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  })
}
