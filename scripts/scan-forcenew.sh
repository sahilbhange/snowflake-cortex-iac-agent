#!/usr/bin/env bash
set -euo pipefail

# Detect and print risky Terraform replacement lines from plan output.
# Usage:
#   terraform plan ... | tee plan.out
#   scripts/scan-forcenew.sh plan.out
# Exit codes:
#   0 = no ForceNew detected (safe to review)
#   2 = ForceNew detected (HIGH RISK — stop and investigate)

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <plan-output-file>"
  exit 1
fi

plan_file="$1"

if [[ ! -f "${plan_file}" ]]; then
  echo "ERROR: plan file not found: ${plan_file}"
  exit 1
fi

if grep -n "# forces replacement" "${plan_file}"; then
  echo ""
  echo "HIGH RISK: plan includes ForceNew replacement actions."
  echo "Do not apply without investigating each replacement above."
  exit 2
fi

echo "OK: no ForceNew replacement lines detected."
