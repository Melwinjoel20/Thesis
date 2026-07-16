output "eb_application_name" { value = module.elastic_beanstalk.application_name }
output "eb_environment_name" { value = module.elastic_beanstalk.environment_name }
output "eb_environment_endpoint" { value = module.elastic_beanstalk.environment_endpoint }
output "eb_security_group_id" { value = aws_security_group.eb_instances.id }
