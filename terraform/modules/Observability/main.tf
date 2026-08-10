
# Module: Observability


#   1. VPC Flow Logs on every VPC        -> network-layer record of every flow
#                                          (5-tuple, action, bytes, packets)
#   2. Client VPN connection log group   -> VPN translation records: username
#                                           (certificate CN), client public IP,
#                                           assigned private IP, timestamps
#   3. API Gateway access log group      -> private-endpoint access with the
#                                           authorised identity attached
#   4. Application log group             -> service interactions with a
#                                           correlation ID



locals {
  base = "${var.name_prefix}-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"

  # Explicit field list: order matters, the analysis script parses positionally.
  flow_log_format = join(" ", [
    "$${version}", "$${vpc-id}", "$${subnet-id}", "$${interface-id}",
    "$${account-id}", "$${srcaddr}", "$${dstaddr}", "$${srcport}", "$${dstport}",
    "$${protocol}", "$${packets}", "$${bytes}", "$${start}", "$${end}",
    "$${action}", "$${log-status}", "$${flow-direction}",
    "$${pkt-srcaddr}", "$${pkt-dstaddr}", "$${traffic-path}",
  ])
}


# 1. Network layer — VPC Flow Logs (one log group per VPC for clean separation)

resource "aws_s3_bucket" "flow" {
  bucket        = "flowlogs-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  force_destroy = true

  tags = merge(var.extra_tags, { Name = "flowlogs-${local.base}", Layer = "network" })
}

resource "aws_s3_bucket_lifecycle_configuration" "flow" {
  bucket = aws_s3_bucket.flow.id
  rule {
    id     = "expire"
    status = "Enabled"
    filter {}
    expiration { days = var.log_retention_days }
  }
}

# Delivery principal must be allowed to write, and to read the bucket ACL.
resource "aws_s3_bucket_policy" "flow" {
  bucket = aws_s3_bucket.flow.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSLogDeliveryWrite"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.flow.arn}/*"
        Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
      },
      {
        Sid       = "AWSLogDeliveryAclCheck"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = ["s3:GetBucketAcl", "s3:ListBucket"]
        Resource  = aws_s3_bucket.flow.arn
      }
    ]
  })
}

resource "aws_flow_log" "vpc" {
  for_each = var.vpc_ids

  vpc_id                   = each.value
  traffic_type             = var.flow_log_traffic_type
  log_destination_type     = "s3"
  log_destination          = "${aws_s3_bucket.flow.arn}/${each.key}/"
  log_format               = local.flow_log_format
  max_aggregation_interval = 60

  tags = merge(var.extra_tags, { Name = "flowlog-${each.key}-${local.base}", Layer = "network" })

  depends_on = [aws_s3_bucket_policy.flow]
}


# 2. VPN layer — Client VPN connection logs (ZETA's "missing" translation log)

resource "aws_cloudwatch_log_group" "vpn" {
  name              = "/${var.product}/${var.environment}/vpn/connections"
  retention_in_days = var.log_retention_days

  tags = merge(var.extra_tags, { Name = "vpn-connections-${local.base}", Layer = "vpn" })
}

resource "aws_cloudwatch_log_stream" "vpn" {
  name           = "connection-log"
  log_group_name = aws_cloudwatch_log_group.vpn.name
}


# 3. Service layer — private API Gateway access logs (identity-attributed)

resource "aws_cloudwatch_log_group" "api" {
  name              = "/${var.product}/${var.environment}/api/access"
  retention_in_days = var.log_retention_days

  tags = merge(var.extra_tags, { Name = "api-access-${local.base}", Layer = "service" })
}


# 4. Application layer — service interactions with correlation IDs

resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.product}/${var.environment}/app/correlation"
  retention_in_days = var.log_retention_days

  tags = merge(var.extra_tags, { Name = "app-correlation-${local.base}", Layer = "application" })
}
