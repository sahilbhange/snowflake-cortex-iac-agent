#!/usr/bin/env bash
# bootstrap.sh — Apply all Snowflake Terraform stacks in dependency order.
#
# Usage: ./bootstrap.sh [ENV]   (ENV defaults to "test")
#
# Each stack maintains its own Terraform state in its own directory.
# Applies are human-gated — you will be prompted before every apply.
# Skipping any step stops the bootstrap; re-run from that step manually.

set -euo pipefail

ENV="${1:-test}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BASE="$REPO_ROOT/live/$ENV"

if [[ ! -d "$BASE" ]]; then
  echo "ERROR: environment directory not found: $BASE"
  exit 1
fi

STEP_NUM=1

step_header() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "  STEP %d: %s\n" "$STEP_NUM" "$1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  STEP_NUM=$((STEP_NUM + 1))
}

apply_stack() {
  local label="$1"
  local stack_rel="$2"   # relative to live/<env>/
  local config="$3"      # filename under configs/
  local note="${4:-}"    # optional warning printed before plan

  step_header "$label"

  if [[ -n "$note" ]]; then
    echo "  ⚠  $note"
    echo ""
  fi

  cd "$BASE/$stack_rel"

  echo "→ terraform init"
  terraform init -upgrade -input=false -no-color 2>&1 | tail -5

  echo ""
  echo "→ terraform plan"
  plan_out=$(mktemp)
  terraform plan -no-color \
    -var-file="../../account.auto.tfvars" \
    -var-file="../../configs/$config" \
    2>&1 | tee "${plan_out}"

  bash "${REPO_ROOT}/scripts/scan-forcenew.sh" "${plan_out}"

  echo ""
  read -r -p "  Apply '$label'? [y/N] " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    terraform apply \
      -var-file="../../account.auto.tfvars" \
      -var-file="../../configs/$config"
    echo "  ✓ Applied"
  else
    echo "  Skipped — continuing to next stack."
  fi

  cd "$REPO_ROOT"
}

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   Snowflake Terraform Bootstrap                      ║"
printf "║   ENV: %-45s║\n" "$ENV"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  Stacks apply in dependency order."
echo "  Each stack owns its own terraform.tfstate."
echo "  You will be prompted [y/N] before every apply."
echo ""

apply_stack \
  "Account Governance — Roles" \
  "account_governance/roles" \
  "create_role.tfvars"

apply_stack \
  "Platform — Databases" \
  "platform/databases" \
  "create_database.tfvars"

apply_stack \
  "Account Governance — Users" \
  "account_governance/users" \
  "create_users.tfvars"

apply_stack \
  "Platform — Warehouses" \
  "platform/warehouses" \
  "create_warehouse.tfvars"

apply_stack \
  "Platform — Resource Monitors" \
  "platform/resource_monitors" \
  "create_resource_monitor.tfvars"

# Stack 6 (Storage Integrations S3) skipped — requires AWS IAM role ARN and S3 bucket.
# Run manually: cd live/<env>/platform/storage_integrations_s3 && terraform apply ...

apply_stack \
  "Workloads — Schemas" \
  "workloads/schemas" \
  "create_schema.tfvars"

apply_stack \
  "Platform — Network Rules" \
  "platform/network_rules" \
  "create_network_rules.tfvars"

apply_stack \
  "Platform — External Access Integrations" \
  "platform/external_access_integrations" \
  "create_external_access_integrations.tfvars" \
  "Requires SnowSQL. Confirm snowsql_connection in account.auto.tfvars is configured."

# Stack 10 (Stages) skipped — depends on storage integration (stack 6).
# Run manually: cd live/<env>/workloads/stages && terraform apply ...

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   Bootstrap complete — all stacks applied            ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
