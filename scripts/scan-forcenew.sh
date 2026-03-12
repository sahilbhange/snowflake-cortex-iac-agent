#!/usr/bin/env bash
set -euo pipefail

# Detect and print risky Terraform changes from plan output.
# Usage:
#   terraform plan ... | tee plan.out
#   scripts/scan-forcenew.sh plan.out
# Exit codes:
#   0 = no risky changes detected (safe to review)
#   2 = risky changes detected (HIGH RISK — stop and investigate)

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <plan-output-file>"
  exit 1
fi

plan_file="$1"

if [[ ! -f "${plan_file}" ]]; then
  echo "ERROR: plan file not found: ${plan_file}"
  exit 1
fi

risky=0

# Check 1: ForceNew replacements
if grep -n "# forces replacement" "${plan_file}"; then
  echo ""
  echo "🔴 HIGH RISK: ForceNew replacement detected"
  risky=1
fi

# Check 2: Name changes (identity change — breaks grants/references)
if grep -E '^\s*~\s+name\s+=' "${plan_file}" | grep -v '(known after apply)'; then
  echo ""
  echo "🔴 HIGH RISK: name change detected (breaks grants, references, auth)"
  risky=1
fi

# Check 3: RSA key removal (lockout risk)
if grep -E 'rsa_public_key.*->.*null' "${plan_file}"; then
  echo ""
  echo "🔴 HIGH RISK: rsa_public_key removal detected (auth lockout risk)"
  risky=1
fi

# Check 4: Password/auth field changes
if grep -E '(password|authenticator).*->' "${plan_file}"; then
  echo ""
  echo "🟡 MEDIUM RISK: auth field change detected"
  risky=1
fi

if [[ $risky -eq 1 ]]; then
  echo ""
  echo "HIGH RISK changes detected. Do not apply without investigating above."
  exit 2
fi

echo "OK: no risky changes detected."
