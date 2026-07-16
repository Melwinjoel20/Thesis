#!/usr/bin/env bash
# =============================================================================
# Packages each REAL Lambda function in infra/lambda/<name>/ into
# infra/lambda/<name>.zip — the paths terraform/usecase/app expects
# (LAMBDA_ZIP_DIR = ../../../infra/lambda).
# Functions use only stdlib + boto3, so no pip step is needed.
# Run from anywhere:  bash scripts/build_lambdas.sh
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/../infra/lambda"

for dir in */; do
  name="${dir%/}"
  [ -f "$dir/lambda_function.py" ] || continue
  echo "packaging ${name}.zip"
  rm -f "${name}.zip"
  (cd "$dir" && zip -q -X -r "../${name}.zip" . -x "*.pyc" -x "__pycache__/*")
done

echo "done:"
ls -1 ./*.zip
