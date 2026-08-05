# R2 Structural Separation — Changeset

This unzips directly into your repo root (files land in correct paths).

## What changed and why
Django previously read DynamoDB directly (products, admin, rate-limit),
violating R2 (presentation tier must have no data-tier path). Now ALL
DynamoDB access goes through app-tier Lambdas, and the DynamoDB gateway
endpoint is REMOVED from the frontend VPC — making R2 structural (no path
exists), not just policy-based.

## Files in this zip
NEW Lambdas:
  infra/lambda/get_products/lambda_function.py      # product catalogue reads
  infra/lambda/manage_products/lambda_function.py   # admin add/list/delete
  infra/lambda/rate_limit/lambda_function.py        # login rate limiting

MODIFIED (overwrite yours):
  store/views.py            # products() invokes Lambda; check_rate_limit shim;
                            # serve_image proxy included
  store/admins_view.py      # admin ops via Lambda
  store/urls.py             # serve_image route
  terraform/usecase/app/main.tf        # 3 new Lambda functions registered
  terraform/usecase/frontend/main.tf   # DynamoDB endpoint removed

## Deploy
1. Unzip into repo root (overwrites the 5 modified files, adds 3 lambda dirs)
2. Review `git diff` — especially views.py, since your live copy may differ
3. Commit and push:
     git add -A
     git commit -m "R2: route all DynamoDB access through Lambda; remove frontend DynamoDB endpoint"
     git push
4. Pipeline auto-builds the new lambda zips (build_lambdas.sh discovers folders)
   and generate_config.py auto-exports the new function names to config.json.

## IMPORTANT verification after deploy
- Products page loads (get-products Lambda working)
- Login still works and throttles after 5 attempts (rate-limit Lambda)
- Admin add/delete product works (manage-products Lambda)
- Confirm R2 structurally: from an SSM session on a frontend instance,
  `aws dynamodb list-tables` should now TIME OUT / fail (no endpoint),
  while the app still works via Lambda. THIS is your R2 evidence — capture it.

## Report note
R2 is now Achieved (structural). Capture the failed direct-DynamoDB attempt
from the frontend tier as evidence before teardown.
