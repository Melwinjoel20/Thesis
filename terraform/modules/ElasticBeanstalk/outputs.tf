output "application_name" {
  value = aws_elastic_beanstalk_application.this.name
}

output "environment_name" {
  value = aws_elastic_beanstalk_environment.this.name
}

output "environment_endpoint" {
  description = "Internal endpoint URL of the EB environment."
  value       = aws_elastic_beanstalk_environment.this.endpoint_url
}
