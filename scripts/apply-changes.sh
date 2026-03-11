#!/usr/bin/env bash
# apply-changes.sh — Multi-stack day-2 workflow: apply, validate, summarise.
# Delegates all plan/apply/safety logic to stack-apply.sh per stack.
#
# Usage:
#   scripts/apply-changes.sh <env> <layer/stack> [<layer/stack> ...]
#
# Examples:
#   scripts/apply-changes.sh test account_governance/roles platform/warehouses
#   scripts/apply-changes.sh test account_governance/roles workloads/schemas account_governance/users

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <env> <layer/stack> [<layer/stack> ...]"
  echo ""
  echo "Examples:"
  echo "  $0 test account_governance/roles platform/warehouses workloads/schemas"
  echo "  $0 test account_governance/roles account_governance/users"
  exit 1
fi

ENV="$1"
shift
STACKS=("$@")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BASE="$REPO_ROOT/live/$ENV"

if [[ ! -d "$BASE" ]]; then
  echo "ERROR: environment directory not found: $BASE"
  exit 1
fi

declare -a APPLIED_STACKS=()
declare -a SKIPPED_STACKS=()
declare -a FAILED_STACKS=()
STEP_NUM=1

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   Day-2 Changes — Plan & Apply                       ║"
printf "║   ENV: %-45s║\n" "$ENV"
printf "║   Stacks: %-42s║\n" "${#STACKS[@]}"
echo "╚══════════════════════════════════════════════════════╝"

for stack_path in "${STACKS[@]}"; do
  layer=$(dirname "$stack_path")
  stack=$(basename "$stack_path")

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "  STEP %d: %s/%s\n" "$STEP_NUM" "$layer" "$stack"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  STEP_NUM=$((STEP_NUM + 1))

  set +e
  bash "${SCRIPT_DIR}/stack-apply.sh" "$ENV" "$layer" "$stack"
  exit_code=$?
  set -e

  case $exit_code in
    0) APPLIED_STACKS+=("$stack_path") ;;
    2) FAILED_STACKS+=("$stack_path (BLOCKED — ForceNew or destroy-only)") ;;
    *) FAILED_STACKS+=("$stack_path (exit $exit_code)") ;;
  esac
done

# ─── Snowflake Validation ────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  SNOWFLAKE VALIDATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SNOW_CONN=""
if [[ -f "$BASE/account.auto.tfvars" ]]; then
  SNOW_CONN=$(grep -o 'snowsql_connection.*=.*"[^"]*"' "$BASE/account.auto.tfvars" 2>/dev/null | sed 's/.*"\([^"]*\)"/\1/' || true)
fi

if [[ -z "$SNOW_CONN" ]]; then
  echo "  ⚠  snowsql_connection not set in account.auto.tfvars — skipping validation."
else
  validate() {
    local label="$1" query="$2"
    echo ""
    echo "  → $label"
    snow sql -c "$SNOW_CONN" -q "$query" 2>/dev/null || echo "    ⚠  Query failed (non-critical)"
  }

  for stack_path in "${APPLIED_STACKS[@]}"; do
    case "$(basename "$stack_path")" in
      roles)             validate "Roles"                  "SHOW ROLES LIKE '%_ROLE';" ;;
      warehouses)        validate "Warehouses"             "SHOW WAREHOUSES LIKE '%_WH';" ;;
      databases)         validate "Databases"              "SHOW DATABASES LIKE '%_DB';" ;;
      schemas)           validate "Schemas (ANALYTICS_DB)" "SHOW SCHEMAS IN DATABASE ANALYTICS_DB;"
                         validate "Schemas (RAW_DB)"       "SHOW SCHEMAS IN DATABASE RAW_DB;" ;;
      users)             validate "Users"                  "SHOW USERS;" ;;
      resource_monitors) validate "Resource Monitors"      "SHOW RESOURCE MONITORS;" ;;
    esac
  done
fi

# ─── Summary ─────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   CHANGE SUMMARY                                     ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
printf "  Environment: %s\n" "$ENV"
printf "  Date:        %s\n" "$(date '+%Y-%m-%d %H:%M')"
echo ""

if [[ ${#APPLIED_STACKS[@]} -gt 0 ]]; then
  echo "  ✓ Applied (${#APPLIED_STACKS[@]}):"
  for s in "${APPLIED_STACKS[@]}"; do echo "    - $s"; done
fi

if [[ ${#SKIPPED_STACKS[@]} -gt 0 ]]; then
  echo ""
  echo "  ⊘ Skipped (${#SKIPPED_STACKS[@]}):"
  for s in "${SKIPPED_STACKS[@]}"; do echo "    - $s"; done
fi

if [[ ${#FAILED_STACKS[@]} -gt 0 ]]; then
  echo ""
  echo "  ✗ Failed/Blocked (${#FAILED_STACKS[@]}):"
  for s in "${FAILED_STACKS[@]}"; do echo "    - $s"; done
fi

echo ""
echo "  Done."
