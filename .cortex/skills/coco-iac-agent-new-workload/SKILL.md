---
name: coco-iac-agent-new-workload
description: Use when onboarding a new team or workload — adding a functional role, warehouse, schemas, and grants. Generates tfvars entries following the existing configs/ pattern and runs terraform plan for each affected stack.
tools:
  - bash
  - read
  - write
  - edit
---

## Skill Metadata
- **Last updated:** 2026-03-11
- **Matches module version:** two-layer RBAC (access roles + functional roles via `granted_roles`)
- **Tested against:** snowflakedb/snowflake ~> 2.14

# New Workload

## When to Use
- Onboarding a new team, squad, or service with a full Snowflake resource set
- Adding role + warehouse + schemas as a bundle
- Expanding an existing workload with new schemas or access patterns

## Goal
Onboard a new squad with the full resource set: access roles → functional role → warehouse → schemas → grants.
One tfvars change per affected stack, plan output for each.

## RBAC Model
This repo uses **two-layer RBAC**. When onboarding a new workload:

1. **Identify or create access roles** for each data layer the team needs (e.g. `FINANCE_READ`, `FINANCE_WRITE`)
2. **Create a functional role** (`FINANCE_ROLE`) that composes the required access roles via `granted_roles`
3. **Assign only the functional role** to users — never access roles directly

```hcl
# create_role.tfvars — access roles first
FINANCE_READ  = { comment = "Read access to finance mart", parent_roles = ["SYSADMIN"] }
FINANCE_WRITE = { comment = "Write access to finance mart", parent_roles = ["SYSADMIN"], granted_roles = ["FINANCE_READ"] }

# then functional role referencing them
FINANCE_ROLE  = { comment = "Finance team functional role", parent_roles = ["SYSADMIN"], granted_roles = ["ANALYTICS_READ", "FINANCE_WRITE"] }
```

## Inputs
- Environment: `test`, `stage`, or `prod`
- Team/workload name → drives naming: `<TEAM>_ROLE`, `<TEAM>_WH`, `<TEAM>_SCHEMA`
- Schemas needed and which databases they belong to
- Access pattern: read-only, read-write, or admin on which databases

## Access Patterns

Access roles own the privileges; functional roles compose them. Map team needs to access roles:

| Team need | Access role to wire via `granted_roles` |
|-----------|----------------------------------------|
| Read raw data | `RAW_READ` |
| Write raw data | `RAW_WRITE` (inherits RAW_READ) |
| Read analytics | `ANALYTICS_READ` |
| Write analytics | `ANALYTICS_WRITE` (inherits ANALYTICS_READ) |
| Team-specific mart (read) | create `<TEAM>_READ` access role |
| Team-specific mart (write) | create `<TEAM>_WRITE` access role (wire `granted_roles = ["<TEAM>_READ"]`) |
| Shared data | `SHARED_READ` or `SHARED_WRITE` |

If an access role for the team's specific schema does not exist yet, create it in `create_role.tfvars` before the functional role.

## Steps
1. Read existing `live/<env>/configs/create_role.tfvars` — follow format exactly
2. Add any new **access roles** the team needs (e.g. `FINANCE_READ`, `FINANCE_WRITE`) under SYSADMIN
3. Add the **functional role** (`<TEAM>_ROLE`) with `granted_roles` pointing to the appropriate access roles
4. Read `create_warehouse.tfvars` — add warehouse with `auto_suspend` and `auto_resume`
5. Read `create_schema.tfvars` — add schemas with correct database and naming
6. **Validate before plan:**
   - Access roles follow `<LAYER>_<PERMISSION>` naming
   - Functional role follows `<TEAM>_ROLE` pattern
   - Functional role uses `granted_roles` — no direct privilege grants on functional role
   - All object names UPPERCASE
   - Env suffix applied: `_TEST` in test, `_STAGE` in stage, none in prod
   - No duplicate grant blocks for same role+object type
7. **REVIEW** — show all tfvars diffs, wait for explicit user confirmation before proceeding
8. **PLAN** — run plans for `roles`, `warehouses`, `schemas` stacks in order (always scan for ForceNew):
   ```bash
   plan_out=$(mktemp)
bash scripts/stack-plan.sh <env> account_governance roles --run 2>&1 | tee "$plan_out"
bash scripts/scan-forcenew.sh "$plan_out"

plan_out=$(mktemp)
bash scripts/stack-plan.sh <env> platform warehouses --run 2>&1 | tee "$plan_out"
bash scripts/scan-forcenew.sh "$plan_out"

plan_out=$(mktemp)
bash scripts/stack-plan.sh <env> workloads schemas --run 2>&1 | tee "$plan_out"
bash scripts/scan-forcenew.sh "$plan_out"
   ```
   Present each plan summary, wait for approval before applying
9. **APPLY** — output apply commands in dependency order, wait for user to confirm completion:
   ```bash
   bash scripts/stack-apply.sh <env> account_governance roles
   bash scripts/stack-apply.sh <env> platform warehouses
   bash scripts/stack-apply.sh <env> workloads schemas
   bash scripts/stack-apply.sh <env> account_governance users   # if users added
   ```
10. **POST-APPLY** ⚠️ **AUTOMATIC** — when user confirms apply completed, immediately run:
    - **State check**: `terraform -chdir=<stack> state list | grep <resource>` for each affected stack
    - **Snowflake validation**: Run `SHOW ROLES/WAREHOUSES/SCHEMAS/USERS LIKE '<name>'` to confirm objects exist
    - Do NOT ask "what's next?" — proceed directly to compliance check
11. **COMPLIANCE** — run compliance checks based on resources created:

    | Resource Type | Applicable Checks |
    |---------------|-------------------|
    | Roles | UPPERCASE naming, `<LAYER>_<PERMISSION>` or `<TEAM>_ROLE` pattern, parent under SYSADMIN, `granted_roles` pattern, provider v2.x, no ACCOUNTADMIN grants |
    | Warehouses | UPPERCASE naming, `auto_suspend` ≤60s, `auto_resume = true` |
    | Schemas | UPPERCASE naming, owner is SYSADMIN |
    | Users | UPPERCASE naming, functional role assigned (not access role), no ACCOUNTADMIN grants |

    Full workload onboarding runs all checks. Partial operations (schema-only, user-only) run only applicable checks.
12. **SUMMARY** — generate formatted change report:
    - All resources created (roles, warehouses, schemas, users)
    - Configuration details (size, auto_suspend, role assignments)
    - Standards compliance status (N/N checks passed)
    - Access summary
    - Next steps (passwords, RSA keys, MFA, additional grants)
13. **GIT PUSH** — after summary, always prompt:
    > "Config files have been updated. Run `$coco-iac-agent-git-push` to generate the branch, commit message, and PR commands for these changes."

## Naming Rules
- Apply env suffix: `MARKETING_ROLE_TEST` in test, `MARKETING_ROLE_STAGE` in stage, `MARKETING_ROLE` in prod
- All Snowflake object names UPPERCASE; tfvars keys UPPERCASE too
- Schema name without `_SCHEMA` suffix — module appends that pattern

## Constraints
- Access roles are never assigned directly to users
- Functional roles must use `granted_roles` to compose access roles — no direct privilege grants
- Role must be parented under SYSADMIN — never ACCOUNTADMIN
- Warehouse must have `auto_suspend` (default 60s) and `auto_resume = true`
- Never create two grant blocks for the same role and object type
- Apply only via `scripts/stack-apply.sh` — never raw `terraform apply`
- Never run `terraform destroy`

## Guardrails
Read `references/guardrails.md` before proceeding -- all safety rules, command format, and stopping points live there.

## Output
- Modified `configs/create_role.tfvars`, `create_warehouse.tfvars`, `create_schema.tfvars` (as applicable)
- `terraform plan` output for each affected stack (roles → warehouses → schemas in order)
- Risk summary if any `# forces replacement` detected

## Examples

### Example 1: Full squad onboarding
User: `$coco-iac-agent-new-workload onboard MARKETING squad in test, read analytics mart, write to MARKETING schema`
Assistant: Reads create_role.tfvars, adds `MARKETING_READ` and `MARKETING_WRITE` access roles under SYSADMIN, then adds `MARKETING_ROLE` functional role with `granted_roles = ["ANALYTICS_READ", "MARKETING_WRITE"]`. Adds `MARKETING_WH_TEST` (XSMALL, auto_suspend=60). Adds ANALYTICS_DB.MARKETING_MART_TEST schema. Runs plans for roles -> warehouses -> schemas stacks, presents each diff before applying.

### Example 2: Schemas only
User: `$coco-iac-agent-new-workload add schema ANALYTICS_DB.FINANCE_MART for FINANCE_ROLE in prod`
Assistant: Reads create_schema.tfvars, adds ANALYTICS_DB.FINANCE_MART entry, runs plan for workloads/schemas only.
