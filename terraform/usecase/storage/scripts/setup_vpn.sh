#!/usr/bin/env bash
# Builds easycart.ovpn from the deployed Client VPN endpoint + terraform certs.
# Run AFTER networking applies with ENABLE_CLIENT_VPN=true:
#   bash scripts/setup_vpn.sh
# Then import easycart.ovpn into the AWS VPN Client (brew install --cask aws-vpn-client)
set -euo pipefail
cd "$(dirname "$0")/.."

TFDIR=terraform/usecase/networking
VPN_ID=$(terraform -chdir=$TFDIR output -raw client_vpn_endpoint_id)

aws ec2 export-client-vpn-client-configuration \
  --client-vpn-endpoint-id "$VPN_ID" \
  --output text > easycart.ovpn

{
  echo "<cert>"
  terraform -chdir=$TFDIR output -raw client_vpn_certificate_pem
  echo "</cert>"
  echo "<key>"
  terraform -chdir=$TFDIR output -raw client_vpn_private_key_pem
  echo "</key>"
} >> easycart.ovpn

echo "wrote easycart.ovpn — import it into the AWS VPN Client and connect."
echo "KEEP THIS FILE PRIVATE (it contains the client key). It is gitignored."
