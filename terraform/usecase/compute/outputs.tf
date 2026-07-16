

output "instance_ids" {
  description = "EC2 instance IDs — use with: aws ssm start-session --target <id>"
  value = {
    hub      = module.hub_ec2.instance_id
    frontend = module.frontend_ec2.instance_id
    app      = module.app_ec2.instance_id
    database = module.database_ec2.instance_id
  }
}

output "instance_private_ips" {
  description = "Private IPs of each instance — use these as ping targets."
  value = {
    hub      = module.hub_ec2.private_ip
    frontend = module.frontend_ec2.private_ip
    app      = module.app_ec2.private_ip
    database = module.database_ec2.private_ip
  }
}

output "ping_matrix" {
  description = "Expected ping results based on your TGW route design."
  value = {
    "hub -> frontend"      = "WORKS   (hub has route to all spokes)"
    "hub -> app"           = "WORKS   (hub has route to all spokes)"
    "hub -> database"      = "WORKS   (hub has route to all spokes)"
    "frontend -> app"      = "WORKS   (route exists)"
    "app -> database"      = "WORKS   (route exists)"
    "frontend -> database" = "FAILS   (no route — zero trust enforced)"
    "database -> frontend" = "FAILS   (no route — zero trust enforced)"
  }
}
