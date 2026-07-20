output "endpoint_id" {
  value = aws_ec2_client_vpn_endpoint.this.id
}

output "client_certificate_pem" {
  value     = tls_locally_signed_cert.client.cert_pem
  sensitive = true
}

output "client_private_key_pem" {
  value     = tls_private_key.client.private_key_pem
  sensitive = true
}
