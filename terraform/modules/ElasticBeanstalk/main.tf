
# Module: ElasticBeanstalk



# EB Application

resource "aws_elastic_beanstalk_application" "this" {
  name        = "${var.name_prefix}-ebs-app-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  description = "EasyCart Elastic Beanstalk Application"

  tags = var.extra_tags
}


# EB Environment — deployed in private subnet of Frontend Spoke VPC


resource "aws_elastic_beanstalk_environment" "this" {
  name                = "${var.name_prefix}-ebs-env-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  application         = aws_elastic_beanstalk_application.this.name
  solution_stack_name = var.solution_stack_name

  # --- Network: private subnet inside Frontend Spoke VPC ---
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = var.vpc_id
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", var.subnet_ids)
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBScheme"
    value     = "internal" # internal only — no public ALB
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBSubnets"
    value     = join(",", var.subnet_ids)
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }

  # Exactly one instance — LoadBalanced only because a fully private VPC
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "HealthCheckPath"
    value     = "/store/home/"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "MatcherHTTPCode"
    value     = "200,302"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "1"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "1"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "false" # no public IPs on EC2 instances
  }

  # --- Environment type ---
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = var.environment_type
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = var.service_role
  }

  # --- Instance profile ---
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = var.instance_profile
  }

  # --- Security group: only allow traffic from Hub VPC CIDR ---
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = var.security_group_id
  }

  # --- Instance type ---
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = var.instance_type
  }

  tags = var.extra_tags
}
