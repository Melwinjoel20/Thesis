# =============================================================================
# Module: ClientVpn
# Description: Point-to-site access into the zero-trust network.
#              AWS Client VPN endpoint, certificate (mutual-TLS) auth, with
#              the whole PKI generated in Terraform: a throwaway CA signs one
#              server and one client certificate, imported into ACM.
#              Split-tunnel: only 10.x traffic rides the VPN. Traffic enters
#              through the hub and is SNATed to the association ENI, so the
#              spokes see it as hub-sourced — existing TGW routes and SG
#              rules apply unchanged.
# NOTE: private keys live in Terraform state — acceptable for a lab/thesis,
#       use a real PKI (ACM PCA) in production.
# =============================================================================

# ---- throwaway PKI ----------------------------------------------------------
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem       = tls_private_key.ca.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = 8760

  subject {
    common_name  = "${var.product}-vpn-ca"
    organization = var.product
  }

  allowed_uses = ["cert_signing", "crl_signing"]
}

resource "tls_private_key" "server" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "server" {
  private_key_pem = tls_private_key.server.private_key_pem

  subject {
    common_name  = "vpn.${var.product}.internal"
    organization = var.product
  }

  dns_names = ["vpn.${var.product}.internal"]
}

resource "tls_locally_signed_cert" "server" {
  cert_request_pem      = tls_cert_request.server.cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = 8760

  allowed_uses = ["key_encipherment", "digital_signature", "server_auth"]
}

resource "tls_private_key" "client" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "client" {
  private_key_pem = tls_private_key.client.private_key_pem

  subject {
    common_name  = "client.${var.product}.internal"
    organization = var.product
  }
}

resource "tls_locally_signed_cert" "client" {
  cert_request_pem      = tls_cert_request.client.cert_request_pem
  ca_private_key_pem    = tls_private_key.ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.ca.cert_pem
  validity_period_hours = 8760

  allowed_uses = ["key_encipherment", "digital_signature", "client_auth"]
}

resource "aws_acm_certificate" "server" {
  private_key       = tls_private_key.server.private_key_pem
  certificate_body  = tls_locally_signed_cert.server.cert_pem
  certificate_chain = tls_self_signed_cert.ca.cert_pem

  tags = merge(var.extra_tags, { Name = "${var.name_prefix}-vpn-server-${var.product}-${var.environment}" })
}

resource "aws_acm_certificate" "client" {
  private_key       = tls_private_key.client.private_key_pem
  certificate_body  = tls_locally_signed_cert.client.cert_pem
  certificate_chain = tls_self_signed_cert.ca.cert_pem

  tags = merge(var.extra_tags, { Name = "${var.name_prefix}-vpn-client-${var.product}-${var.environment}" })
}

# ---- the endpoint -----------------------------------------------------------
resource "aws_security_group" "vpn" {
  name        = "${var.name_prefix}-sg-vpn-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  description = "Client VPN association ENIs"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.extra_tags, {
    Name = "${var.name_prefix}-sg-vpn-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  })
}

resource "aws_ec2_client_vpn_endpoint" "this" {
  description            = "${var.product} point-to-site (${var.environment})"
  server_certificate_arn = aws_acm_certificate.server.arn
  client_cidr_block      = var.client_cidr
  split_tunnel           = true
  vpc_id                 = var.vpc_id
  security_group_ids     = [aws_security_group.vpn.id]
  dns_servers            = [var.vpc_dns_resolver]

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.client.arn
  }

  connection_log_options {
    enabled = false
  }

  tags = merge(var.extra_tags, {
    Name = "${var.name_prefix}-vpn-${var.product}-${var.environment}-${var.region_short}-${var.name_suffix}"
  })
}

resource "aws_ec2_client_vpn_network_association" "hub" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  subnet_id              = var.association_subnet_id
}

resource "aws_ec2_client_vpn_authorization_rule" "internal" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  target_network_cidr    = "10.0.0.0/8"
  authorize_all_groups   = true
}

resource "aws_ec2_client_vpn_route" "spokes" {
  for_each = toset(var.spoke_cidrs)

  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  destination_cidr_block = each.value
  target_vpc_subnet_id   = aws_ec2_client_vpn_network_association.hub.subnet_id

  timeouts {
    create = "15m"
    delete = "15m"
  }
}
