output "bucket_name" { value = module.s3.bucket_name }
output "bucket_arn" { value = module.s3.bucket_arn }
output "vpc_endpoint_id" { value = module.s3.vpc_endpoint_id }
output "bucket_name" {
  value = aws_s3_bucket.this.bucket
}