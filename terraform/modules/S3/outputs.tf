output "bucket_name" {
  value = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}

output "vpc_endpoint_id" {
  value = try(aws_vpc_endpoint.s3[0].id, null)
}
