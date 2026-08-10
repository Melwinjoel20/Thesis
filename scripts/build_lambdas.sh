#!/usr/bin/env bash

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
