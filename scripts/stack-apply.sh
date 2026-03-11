#!/usr/bin/env bash
# stack-apply.sh — Safe terraform apply with pre-flight validation.
#
# Usage:
#   scripts/stack-apply.sh <env> <layer> <resource> [--auto-approve]
#
# Options:
#   --auto-approve   Skip interactive confirmation (for CI only — safety checks still run)
#
# Examples:
#   scripts/stack-apply.sh test platform warehouses
#   scripts/stack-apply.sh test account_governance roles
#
# Safety checks before apply:
#   1. Config tfvars file exists
#   2. account.auto.tfvars exists
#   3. Mandatory plan before apply (no skipping)
#   4. ForceNew detection (HIGH RISK)
#   5. Destroy-only detection (all resources destroyed, none added)
#   6. Empty for_each detection (config file not loaded correctly)
#   7. Resource count sanity check (destroy > add = warning)
#   8. Human confirmation with clear summary
#
# Common Terraform edge cases this prevents:
#   - Missing -var-file → empty for_each → destroys all resources
#   - Broken line continuation (\) → second var-file silently dropped
#   - Wrong config file → mismatched resources planned for destroy
#   - Applying without reviewing plan → accidental destructive changes
#   - ForceNew on databases/warehouses/roles → drop + recreate = data loss

set -euo pipefail

# ─── TTY Guard ───────────────────────────────────────────────────────
# Refuses to run in any non-interactive session (CI pipelines, AI agents, scripts).
# Apply is a human action — a TTY must be attached.
if [[ ! -t 0 ]]; then
  echo "ERROR: stack-apply.sh requires an interactive terminal (TTY)."
  echo "       This script must be run directly by a human — not via AI, CI, or pipe."
  echo ""
  echo "       If you are seeing this from CoCo: copy the command and run it in your terminal."
  exit 1
fi

# ─── Argument Parsing ────────────────────────────────────────────────

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <env> <layer> <resource> [--auto-approve]"
  echo ""
  echo "Examples:"
  echo "  $0 test platform warehouses"
  echo "  $0 test account_governance roles"
  echo "  $0 test workloads schemas"
  echo ""
  echo "Options:"
  echo "  --auto-approve   Skip interactive confirmation (safety checks still run)"
  exit 1
fi

env_name="$1"
layer="$2"
resource="$3"
auto_approve=false

for arg in "${@:4}"; do
  case "$arg" in
    --auto-approve) auto_approve=true ;;
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

# ─── Pre-Flight Checks ──────────────────────────────────────────────

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
  echo "    This would cause Terraform to use empty defaults → DESTROY ALL RESOURCES"
  ERRORS=$((ERRORS + 1))
else
  echo "  ✓ Config file found: configs/$config_file"
fi

# Check 4: Config file is not empty
if [[ -f "$config_tfvars" ]] && [[ ! -s "$config_tfvars" ]]; then
  echo "  ✗ Config file is empty: configs/$config_file"
  echo "    Empty config → empty for_each map → DESTROY ALL RESOURCES"
  ERRORS=$((ERRORS + 1))
else
  echo "  ✓ Config file is not empty"
fi

if [[ $ERRORS -gt 0 ]]; then
  echo ""
  echo "  BLOCKED: $ERRORS pre-flight check(s) failed. Fix before proceeding."
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

# ─── Terraform Plan (mandatory) ──────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TERRAFORM PLAN"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

plan_out=$(mktemp)
if ! terraform plan -no-color \
  -var-file="../../account.auto.tfvars" \
  -var-file="../../configs/$config_file" \
  2>&1 | tee "${plan_out}"; then
  echo ""
  echo "  ✗ Plan failed — cannot proceed with apply."
  exit 1
fi

# ─── Plan Analysis ───────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PLAN ANALYSIS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

BLOCKED=false

# Check: No changes needed
if grep -q "No changes. Your infrastructure matches the configuration." "${plan_out}"; then
  echo "  → No changes needed. Nothing to apply."
  cd "$REPO_ROOT"
  exit 0
fi

# Extract counts from plan summary (macOS-compatible — no -P flag)
adds=$(grep -o '[0-9]* to add' "${plan_out}" | grep -o '[0-9]*' || echo "0")
changes=$(grep -o '[0-9]* to change' "${plan_out}" | grep -o '[0-9]*' || echo "0")
destroys=$(grep -o '[0-9]* to destroy' "${plan_out}" | grep -o '[0-9]*' || echo "0")

echo "  Plan summary: +${adds} add, ~${changes} change, -${destroys} destroy"

# Safety 1: ForceNew detection
if grep -q "# forces replacement" "${plan_out}"; then
  echo ""
  echo "  ⚠  HIGH RISK: ForceNew replacement detected!"
  echo "     Resources will be DESTROYED and RECREATED."
  echo "     For databases/roles this means DATA LOSS."
  grep -n "# forces replacement" "${plan_out}" | sed 's/^/     /'
  BLOCKED=true
fi

# Safety 2: Destroy-only plan (0 adds, >0 destroys)
if [[ "$adds" == "0" ]] && [[ "$destroys" -gt 0 ]]; then
  echo ""
  echo "  🛑 CRITICAL: Destroy-only plan detected!"
  echo "     0 resources to add, ${destroys} to destroy."
  echo ""
  echo "     Common causes:"
  echo "     - Config tfvars file not loaded (missing -var-file or broken line continuation)"
  echo "     - enable_<resource> set to false"
  echo "     - Empty resource map in tfvars"
  echo ""
  echo "     Verify: does configs/$config_file contain the resources shown above?"
  BLOCKED=true
fi

# Safety 3: "not in for_each map" — empty map indicator
if grep -q "is not in for_each map" "${plan_out}"; then
  echo ""
  echo "  🛑 CRITICAL: Empty for_each map detected!"
  echo "     Resources are being destroyed because their keys are missing from the map."
  echo "     This usually means the config tfvars was not loaded."
  echo ""
  echo "     Check that configs/$config_file is being passed correctly."
  BLOCKED=true
fi

# Safety 4: More destroys than adds (suspicious)
if [[ "$destroys" -gt 0 ]] && [[ "$destroys" -gt "$adds" ]]; then
  if [[ "$BLOCKED" != "true" ]]; then
    echo ""
    echo "  ⚠  WARNING: More resources destroyed (${destroys}) than added (${adds})."
    echo "     Review the plan carefully before proceeding."
  fi
fi

# Safety 5: Large number of destroys
if [[ "$destroys" -ge 5 ]]; then
  if [[ "$BLOCKED" != "true" ]]; then
    echo ""
    echo "  ⚠  WARNING: ${destroys} resources will be destroyed."
    echo "     This is a high-impact change — review carefully."
  fi
fi

if [[ "$BLOCKED" == "true" ]]; then
  echo ""
  echo "  ────────────────────────────────────────"
  echo "  APPLY BLOCKED — resolve the issues above before proceeding."
  echo ""
  echo "  If you are CERTAIN this is intentional, use terraform apply directly:"
  echo "    cd $stack_dir && \\"
  echo "      terraform apply \\"
  echo "        -var-file=../../account.auto.tfvars \\"
  echo "        -var-file=../../configs/$config_file"
  cd "$REPO_ROOT"
  exit 2
fi

# ─── Apply Confirmation ─────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  APPLY CONFIRMATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Environment: $env_name"
echo "  Stack:       $layer/$resource"
echo "  Config:      configs/$config_file"
echo "  Changes:     +${adds} add, ~${changes} change, -${destroys} destroy"
echo ""

if [[ "$auto_approve" == "true" ]]; then
  echo "  --auto-approve: skipping confirmation."
else
  read -r -p "  Apply these changes? [y/N] " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "  Cancelled."
    cd "$REPO_ROOT"
    exit 0
  fi
fi

# ─── Terraform Apply ─────────────────────────────────────────────────

echo ""
terraform apply -auto-approve \
  -var-file="../../account.auto.tfvars" \
  -var-file="../../configs/$config_file"

echo ""
echo "  ✓ Applied: $layer/$resource"

# ─── Post-Apply State Check ─────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  POST-APPLY STATE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

terraform state list | sed 's/^/  /'

cd "$REPO_ROOT"

echo ""
echo "  Done."
