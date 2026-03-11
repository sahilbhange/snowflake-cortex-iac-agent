#!/usr/bin/env bash
# stack-plan.sh — Safe terraform plan with pre-flight validation.
#
# Usage:
#   scripts/stack-plan.sh <env> <layer> <resource> [--run] [--drift]
#
# Options:
#   --run    Execute the plan (otherwise prints the command only)
#   --drift  Add -detailed-exitcode (for drift detection / exit code checks)
#
# Examples:
#   scripts/stack-plan.sh test platform databases --run
#   scripts/stack-plan.sh stage account_governance roles --run --drift
#
# Pre-flight checks (when --run):
#   1. Stack directory exists
#   2. account.auto.tfvars exists
#   3. Config tfvars file exists (missing = empty for_each = misleading plan)
#   4. Config file is not empty

set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <env> <layer> <resource> [--run] [--drift]"
  echo ""
  echo "Examples:"
  echo "  $0 test platform databases --run"
  echo "  $0 stage account_governance roles --run --drift"
  exit 1
fi

env_name="$1"
layer="$2"
resource="$3"
run_mode=false
drift_mode=false

for arg in "${@:4}"; do
  case "$arg" in
    --run)   run_mode=true ;;
    --drift) drift_mode=true ;;
    *) echo "ERROR: unknown option '$arg'"; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BASE="$REPO_ROOT/live/$env_name"

# ─── Config File Resolution ─────────────────────────────────────────

case "${resource}" in
  roles)                          config_file="create_role.tfvars" ;;
  databases)                      config_file="create_database.tfvars" ;;
  warehouses)                     config_file="create_warehouse.tfvars" ;;
  users)                          config_file="create_users.tfvars" ;;
  schemas)                        config_file="create_schema.tfvars" ;;
  resource_monitors)              config_file="create_resource_monitor.tfvars" ;;
  network_rules)                  config_file="create_network_rules.tfvars" ;;
  storage_integrations_s3)        config_file="create_storage_integration_s3.tfvars" ;;
  external_access_integrations)   config_file="create_external_access_integrations.tfvars" ;;
  stages)                         config_file="create_stage_s3.tfvars" ;;
  *)
    echo "ERROR: unknown resource '${resource}'"
    exit 1
    ;;
esac

stack_dir="$BASE/$layer/$resource"
account_tfvars="$BASE/account.auto.tfvars"
config_tfvars="$BASE/configs/$config_file"

# ─── Print Command (always) ─────────────────────────────────────────

drift_flags=""
if [[ "${drift_mode}" == true ]]; then
  drift_flags=" -detailed-exitcode"
fi

echo "Stack:   live/$env_name/$layer/$resource"
echo "Command: terraform plan -no-color${drift_flags} -var-file=../../account.auto.tfvars -var-file=../../configs/$config_file"

if [[ "${run_mode}" != true ]]; then
  exit 0
fi

# ─── Pre-Flight Checks (only when --run) ─────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PRE-FLIGHT CHECKS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ERRORS=0

# Check 1: Stack directory exists
if [[ ! -d "$stack_dir" ]]; then
  echo "  ✗ Stack directory not found: $stack_dir"
  ERRORS=$((ERRORS + 1))
else
  echo "  ✓ Stack directory exists: $layer/$resource"
fi

# Check 2: account.auto.tfvars exists
if [[ ! -f "$account_tfvars" ]]; then
  echo "  ✗ account.auto.tfvars not found: $account_tfvars"
  ERRORS=$((ERRORS + 1))
else
  echo "  ✓ account.auto.tfvars found"
fi

# Check 3: Config tfvars exists
if [[ ! -f "$config_tfvars" ]]; then
  echo "  ✗ Config file not found: configs/$config_file"
  echo "    Missing config → empty for_each → plan will show DESTROY ALL RESOURCES"
  ERRORS=$((ERRORS + 1))
else
  echo "  ✓ Config file found: configs/$config_file"
fi

# Check 4: Config file is not empty
if [[ -f "$config_tfvars" ]] && [[ ! -s "$config_tfvars" ]]; then
  echo "  ✗ Config file is empty: configs/$config_file"
  echo "    Empty config → empty for_each map → misleading destroy plan"
  ERRORS=$((ERRORS + 1))
else
  echo "  ✓ Config file is not empty"
fi

if [[ $ERRORS -gt 0 ]]; then
  echo ""
  echo "  BLOCKED: $ERRORS pre-flight check(s) failed. Fix before running plan."
  exit 1
fi

echo ""
echo "  All pre-flight checks passed."

# ─── Terraform Init ──────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TERRAFORM INIT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$stack_dir"
terraform init -upgrade -input=false -no-color 2>&1 | tail -5

# ─── Terraform Plan ──────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TERRAFORM PLAN"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "${drift_mode}" == true ]]; then
  terraform plan -no-color -detailed-exitcode \
    -var-file="../../account.auto.tfvars" \
    -var-file="../../configs/$config_file"
else
  terraform plan -no-color \
    -var-file="../../account.auto.tfvars" \
    -var-file="../../configs/$config_file"
fi

cd "$REPO_ROOT"
