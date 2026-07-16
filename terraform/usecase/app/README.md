# Use Case: App (Phase 4)

Run this **after** `usecase/networking` is applied. All VPC / subnet IDs are read
from the networking layer's state automatically — nothing to copy-paste.

## What gets deployed (App Spoke)

| Resource                       | Purpose                                        |
|--------------------------------|------------------------------------------------|
| Cognito user pool + client     | OAuth 2.0 / JWT identity for EasyCart          |
| Lambda x5 (private subnets)    | add-to-cart, view-cart, remove-cart-item, place-order, tax-calculator |
| SNS topic                      | `EasyCartOrderNotifications` (place-order publishes here) |
| Lambda security group          | Egress-only                                    |
| DynamoDB **Gateway** endpoint  | Lambdas reach DynamoDB with no internet path   |
| SNS **Interface** endpoint     | place-order reaches SNS with no internet path  |

The two endpoints matter: the App VPC has no IGW/NAT, so without them every
boto3 call inside Lambda hangs until timeout.

## Steps

```bash
# 1. Build the deployment zips (stdlib + boto3 only, no pip step)
bash ../../lambda/build.sh

# 2. Deploy
terraform init
terraform plan
terraform apply

# Destroy when done (Learner Lab budget)
terraform destroy
```

To get order emails, set `ORDER_NOTIFICATION_EMAIL` in `terraform.tfvars`
and confirm the subscription email SNS sends you.

## Test a function (from the hub instance or CloudShell)

```bash
aws lambda invoke --function-name $(terraform output -json lambda_function_names | jq -r '."tax-calculator"') \
  --payload '{"subtotal": 100, "region_code": "IE"}' --cli-binary-format raw-in-base64-out /tmp/out.json
cat /tmp/out.json
```

Note: the cart/order functions need the `usecase/database` tables
(UserCart, Orders) to exist — apply that stack first.
