# =============================================================================
# Use Case: Networking — Outputs
# =============================================================================

output "transit_gateway_id" {
  description = "Transit Gateway ID."
  value       = module.transit_gateway.transit_gateway_id
}

output "vpc_ids" {
  description = "All VPC IDs."
  value = {
    hub      = module.hub_vpc.vpc_id
    frontend = module.frontend_vpc.vpc_id
    app      = module.app_vpc.vpc_id
    database = module.database_vpc.vpc_id
  }
}

output "subnet_ids" {
  description = "Subnet IDs per VPC."
  value = {
    hub      = module.hub_vpc.subnet_ids
    frontend = module.frontend_vpc.subnet_ids
    app      = module.app_vpc.subnet_ids
    database = module.database_vpc.subnet_ids
  }
}

output "route_table_ids" {
  description = "Route table IDs per VPC."
  value = {
    hub      = module.hub_vpc.route_table_ids
    frontend = module.frontend_vpc.route_table_ids
    app      = module.app_vpc.route_table_ids
    database = module.database_vpc.route_table_ids
  }
}

output "execute_api_endpoint_id" {
  description = "Hub execute-api Interface endpoint — entry to the internal private API."
  value       = module.hub_api_ingress.endpoint_ids["execute-api"]
}

output "client_vpn_endpoint_id" {
  value = var.ENABLE_CLIENT_VPN ? module.client_vpn[0].endpoint_id : null
}

output "client_vpn_certificate_pem" {
  value     = var.ENABLE_CLIENT_VPN ? module.client_vpn[0].client_certificate_pem : null
  sensitive = true
}

output "client_vpn_private_key_pem" {
  value     = var.ENABLE_CLIENT_VPN ? module.client_vpn[0].client_private_key_pem : null
  sensitive = true
}
