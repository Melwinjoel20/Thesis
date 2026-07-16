# =============================================================================
# Module: DynamoDB
# Description: Creates DynamoDB tables dynamically from the tables map.
#              PAY_PER_REQUEST billing — no capacity planning needed.
# =============================================================================

resource "aws_dynamodb_table" "this" {
  for_each = var.tables

  name         = each.key
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = each.value.hash_key
  range_key    = each.value.range_key

  attribute {
    name = each.value.hash_key
    type = each.value.hash_key_type
  }

  dynamic "attribute" {
    for_each = each.value.range_key != null ? [1] : []
    content {
      name = each.value.range_key
      type = each.value.range_key_type
    }
  }

  dynamic "attribute" {
    for_each = each.value.additional_attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  tags = merge(var.extra_tags, {
    Name = "${var.name_prefix}-ddb-${each.key}-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  })
}
