---
name: coco-iac-agent-new-role-user
description: Use when adding a Snowflake user, assigning roles, or making RBAC changes. Generates entries for create_users.tfvars and create_role.tfvars, validates role hierarchy, and runs plans for the account_governance stacks.
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

# New Role / User

## When to Use
- Adding a new human user or service account to Snowflake
- Assigning a role to a user
- Creating a new functional role
- Updating RBAC: role grants, privilege changes, role membership

## Goal
Add users and RBAC changes with least-privilege and correct two-layer role hierarchy.
Validates hierarchy before generating any changes — no ACCOUNTADMIN grants, no access roles assigned to users.

## RBAC Model
This repo uses **two-layer RBAC**:
- **Access Roles** (`<LAYER>_<PERMISSION>`, e.g. `RAW_READ`, `ANALYTICS_WRITE`) — own object privileges; **never assigned to users**
- **Functional Roles** (`<TEAM>_ROLE`, e.g. `ENGINEER_ROLE`, `ANALYST_ROLE`) — assigned to users; composed via `granted_roles` in `create_role.tfvars`

When creating a new functional role, wire access roles via `granted_roles`, not direct privilege grants.

```hcl
# create_role.tfvars example — new functional role
FINANCE_ROLE = {
  comment      = "Finance team — read analytics, write finance mart"
  parent_roles = ["SYSADMIN"]
  granted_roles = ["ANALYTICS_READ", "FINANCE_WRITE"]
}
```

## Inputs
- Environment: `test`, `stage`, or `prod`
- User: `name`, `email`, `first_name`, `last_name`
- `default_role`, `default_warehouse`
- Roles to assign (list)
- Workspace schema: yes/no (auto-created in WORKSPACE_DB if yes)
- Network policy name (optional)

## Steps
1. Read `live/<env>/configs/create_users.tfvars` — match format exactly
2. Add user entry with all required fields
3. If new role needed: add to `create_role.tfvars` under SYSADMIN
4. **REVIEW** — show the tfvars diff, wait for explicit user confirmation before proceeding
5. **PLAN** — run plan for the affected stacks (always scan for ForceNew):
   ```bash
   plan_out=$(mktemp)
bash scripts/stack-plan.sh <env> account_governance roles --run 2>&1 | tee "$plan_out"   # if new role added
bash scripts/scan-forcenew.sh "$plan_out"

plan_out=$(mktemp)
bash scripts/stack-plan.sh <env> account_governance users --run 2>&1 | tee "$plan_out"
bash scripts/scan-forcenew.sh "$plan_out"
   ```
   Present plan summary with RBAC risk notes, wait for approval before applying
6. **APPLY** — after user confirms plan, apply each stack in dependency order:
   ```bash
   bash scripts/stack-apply.sh <env> account_governance roles   # only if new role added
   bash scripts/stack-apply.sh <env> account_governance users
   ```
   Pause between stacks — wait for confirmation before each apply.
7. **POST-APPLY** — follow `references/workflow.md` Post-Apply Checklist (state check + Snowflake validation).
9. **COMPLIANCE** — check against Snowflake standards:
   - User `login_name` not changed on existing user (ForceNew risk)
   - Role name follows `<TEAM>_ROLE` pattern
   - Role hierarchy: custom role under SYSADMIN, not ACCOUNTADMIN
   - `default_role` matches assigned role
   - `default_warehouse` matches team warehouse
   - `must_change_password = true` for human users with password auth
   - No ACCOUNTADMIN grants
9. **SUMMARY** — generate change report:
    - User created (name, email, login_name)
    - Role assigned
    - Workspace schema created (yes/no, location in WORKSPACE_DB)
    - Standards compliance status
    - Next steps: set password or RSA key, enroll in MFA
10. **GIT PUSH** — after summary, always prompt:
    > "Config files have been updated. Run `$coco-iac-agent-git-push` to generate the branch, commit message, and PR commands for these changes."

## Key Rules
- `login_name` is ForceNew — never change on an existing user
- `workspace_schema_database` must match the top-level var (`WORKSPACE_DB`)
- Never grant ACCOUNTADMIN to service or functional roles
- `must_change_password = true` for human users with password auth
- `rsa_public_key` for service accounts — never hardcode key content, use file reference

## Grant Generation
- One `snowflake_grant_privileges_to_account_role` block per role per object type
- Consolidate all privileges for same role+object into single block
- Never generate duplicate grant blocks — causes perpetual drift
- Use `all_privileges = true` sparingly; prefer explicit privilege lists

## Constraints
- Apply only via `scripts/stack-apply.sh` — CoCo outputs the command, user runs it
- Never run `terraform destroy`
- Validate role name follows `<TEAM>_ROLE` convention before generating

## Guardrails
Read `references/guardrails.md` before proceeding -- all safety rules, command format, and stopping points live there.

## Output
- Modified `configs/create_users.tfvars` (and `create_role.tfvars` if a new role was added)
- `terraform plan` output for `account_governance/users` (and `account_governance/roles` if changed)
- RBAC risk notes for any privilege expansion or ACCOUNTADMIN proximity

## Examples

### Example 1: New human user
User: `$coco-iac-agent-new-role-user add jsmith, jsmith@company.com, ANALYST_ROLE, ANALYST_WH, prod`
Assistant: Reads create_users.tfvars, adds JSMITH entry with must_change_password=true and workspace schema. Runs plan for account_governance/users. Flags any ForceNew.

### Example 2: New service account
User: `$coco-iac-agent-new-role-user add service account ETL_SVC for ETL_ROLE in test, RSA auth`
Assistant: Adds ETL_SVC_TEST to create_users.tfvars with rsa_public_key reference (no hardcoded key), must_change_password=false. Runs plan for account_governance/users.

### Example 3: New role only
User: `$coco-iac-agent-new-role-user create REPORTING_ROLE in prod, parent SYSADMIN`
Assistant: Reads create_role.tfvars, adds REPORTING_ROLE under SYSADMIN. Runs plan for account_governance/roles.
