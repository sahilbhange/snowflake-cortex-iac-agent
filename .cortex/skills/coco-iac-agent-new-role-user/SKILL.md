---
name: coco-iac-agent-new-role-user
description: Use when adding a Snowflake user (human or service), assigning roles, or making RBAC changes. Generates entries for create_users.tfvars, create_service_users.tfvars, and create_role.tfvars, validates role hierarchy, and runs plans for the account_governance stacks.
tools:
  - bash
  - read
  - write
  - edit
---

## Skill Metadata
- **Last updated:** 2026-03-26
- **Matches module version:** two-layer RBAC (access roles + functional roles via `granted_roles`)
- **Tested against:** snowflakedb/snowflake ~> 2.14

# New Role / User

## When to Use
- Adding a new human user or service account to Snowflake
- Adding a new service user (TYPE=SERVICE, key-pair auth only) via `snowflake_service_user`
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

## Service Users (TYPE=SERVICE)

For **non-interactive service accounts** (dbt, CI/CD runners, ETL pipelines), use `snowflake_service_user` instead of `snowflake_user`. This enforces TYPE=SERVICE at the Snowflake level — no password, no interactive login, key-pair auth only.

| Attribute | `snowflake_user` (human/legacy) | `snowflake_service_user` (v2.x) |
|---|---|---|
| Resource | `snowflake_user` | `snowflake_service_user` |
| Stack | `account_governance/users` | `account_governance/service_users` |
| Config | `create_users.tfvars` | `create_service_users.tfvars` |
| Provider | `secadmin` | `secadmin` |
| Auth | Password or RSA key | RSA key only (no password) |
| Interactive login | Yes | No |

**Decision rule:** If the account will be used by a human → `snowflake_user`. If by an application/service → `snowflake_service_user`.

### Service User tfvars pattern
```hcl
# create_service_users.tfvars
service_users = {
  DBT_SVC = {
    login_name        = "dbt_svc"
    display_name      = "dbt Service Account"
    disabled          = false
    default_role      = "DBT_ROLE"
    default_warehouse = "DBT_WH"
    rsa_public_key    = null        # set after creation or via key rotation
    rsa_public_key_2  = null
    comment           = "dbt Cloud service account — key-pair auth only"
    granted_roles     = ["DBT_ROLE"]
  }
}
```

## Inputs
- Environment: `test`, `stage`, or `prod`
- User: `name`, `email`, `first_name`, `last_name`
- `default_role`, `default_warehouse`
- Roles to assign (list)
- Workspace schema: yes/no (auto-created in workspace database if yes)
- Network policy name (optional)

## Steps
1. **Detect user type** — Is this a service user (non-interactive, key-pair only) or a human user?
   - Service user → use `create_service_users.tfvars` + `account_governance/service_users` stack
   - Human user → use `create_users.tfvars` + `account_governance/users` stack
2. **NAME PROPOSAL** — before touching any file, read `references/naming-conventions.md`, scan existing `live/<env>/configs/create_users.tfvars`, `create_service_users.tfvars`, and `create_role.tfvars` for conflicts, then present:
   ```
   ## Name Proposal — <request summary> — <env>

   | Object Type    | Proposed Name        | Convention Applied                   | Conflict |
   |----------------|----------------------|--------------------------------------|----------|
   | User login     | jsmith               | lowercase <first initial><last>      | None     |
   | User object    | JSMITH               | UPPERCASE of login name              | None     |
   | Functional role| <TEAM>_ROLE[_TEST]   | <TEAM>_ROLE + env suffix (if new)    | None     |
   | Workspace schema| WORKSPACE_DB.JSMITH | WORKSPACE_DB.<LOGIN_UPPER>           | None     |

   Approve these names, or reply with corrections before I generate any files.
   ```
   **GATE: Do not read or edit any tfvars until the user approves names.**
   Flag `login_name` collisions (two users with same first initial + last name) in the Conflict column.
3. Read the appropriate tfvars file — `create_users.tfvars` (human) or `create_service_users.tfvars` (service) — match format exactly
4. Add user entry with all required fields (using approved names)
5. If new role needed: add to `create_role.tfvars` under SYSADMIN (using approved name)
6. **REVIEW** — show the tfvars diff, wait for explicit user confirmation before proceeding
7. **PLAN** — run plan for the affected stacks (always scan for ForceNew):
   ```bash
   plan_out=$(mktemp)
   bash scripts/stack-plan.sh <env> account_governance roles --run 2>&1 | tee "$plan_out"   # if new role added
   bash scripts/scan-forcenew.sh "$plan_out"

   # For human users:
   plan_out=$(mktemp)
   bash scripts/stack-plan.sh <env> account_governance users --run 2>&1 | tee "$plan_out"
   bash scripts/scan-forcenew.sh "$plan_out"

   # For service users:
   plan_out=$(mktemp)
   bash scripts/stack-plan.sh <env> account_governance service_users --run 2>&1 | tee "$plan_out"
   bash scripts/scan-forcenew.sh "$plan_out"
   ```
   Present plan summary with RBAC risk notes, wait for approval before applying
8. **APPLY** — after user confirms plan, output apply commands (never execute):
   ```bash
   bash scripts/stack-apply.sh <env> account_governance roles          # only if new role added
   bash scripts/stack-apply.sh <env> account_governance users          # for human users
   bash scripts/stack-apply.sh <env> account_governance service_users  # for service users
   ```
   Pause between stacks — wait for confirmation before each apply.
9. **POST-APPLY** — follow `references/workflow.md` Post-Apply Checklist (state check + Snowflake validation).
10. **COMPLIANCE** — check against Snowflake standards (naming was pre-approved in NAME PROPOSAL — see `references/naming-conventions.md`):
   - User `login_name` not changed on existing user (ForceNew risk)
   - Role hierarchy: custom role under SYSADMIN, not ACCOUNTADMIN
   - `default_role` matches assigned role
   - `default_warehouse` matches team warehouse
   - `must_change_password = true` for human users with password auth
   - Service users: no password set, `rsa_public_key` placeholder or real key, `snowflake_service_user` resource used (not `snowflake_user`)
   - No ACCOUNTADMIN grants
11. **SUMMARY** — generate change report:
    - User created (name, email, login_name)
    - Role assigned
    - Workspace schema created (yes/no, location in WORKSPACE_DB)
    - Standards compliance status
    - Next steps: set password or RSA key, enroll in MFA
12. **GIT PUSH** — after summary, always prompt:
    > "Config files have been updated. Run `$coco-iac-agent-git-push` to generate the branch, commit message, and PR commands for these changes."

## Key Rules
- `login_name` is ForceNew — never change on an existing user
- `workspace_schema_database` must match the workspace database defined in `create_database.tfvars`
- `must_change_password = true` for human users with password auth
- `rsa_public_key` for service accounts — never hardcode key content, use file reference
- New service accounts must use `snowflake_service_user` (not `snowflake_user`) — enforces TYPE=SERVICE

All other safety/naming/RBAC rules enforced via `cortex ctx` rules.

## Provisioning User (Terraform Account)

⚠️ **The user running Terraform (provisioning account) CAN be managed in state** but with safeguards:

**Identify provisioning user** — check `live/<env>/account.auto.tfvars`:
```hcl
provisioning_user = "USERNAME"  # exact Snowflake username case
```

**Module protection** — `modules/users/main.tf` includes `lifecycle.ignore_changes` for:
- `rsa_public_key` — prevents auth lockout
- `password` — preserves credentials
- `default_namespace` — prevents session disruption
- `default_secondary_roles_option` — preserves role config

**When importing provisioning user:**
1. Read `provisioning_user` from `account.auto.tfvars`
2. Use tfvars key matching EXACT Snowflake username case
3. Import with: `terraform import ... '<USERNAME>'`
4. Verify plan shows NO changes to auth fields (ignored by lifecycle)

**tfvars entry for provisioning user** — do NOT include auth fields:
```hcl
<PROVISIONING_USER> = {
  first_name        = "..."
  last_name         = "..."
  email             = "..."
  default_role      = "..."
  default_warehouse = "..."
  roles             = [...]
}
```
Note: `rsa_public_key` NOT included — module ignores changes to this field, preserving existing key.

## Grant Generation
- One `snowflake_grant_privileges_to_account_role` block per role per object type
- Consolidate all privileges for same role+object into single block
- Never generate duplicate grant blocks — causes perpetual drift
- Use `all_privileges = true` sparingly; prefer explicit privilege lists

## Constraints
Safety, naming, RBAC, and workflow rules are enforced via `cortex ctx` rules.
Run `cortex ctx rule list` to review. See `docs/RULES_REFERENCE.md` for the full catalog.

## Guardrails
See `cortex ctx` rules — replaces `references/guardrails.md` for behavioral enforcement.

## References
- `references/naming-conventions.md` — object naming patterns, NAME PROPOSAL format, conflict detection
- `references/guardrails.md` — safety rules, command format
- `references/rbac-design.md` — two-layer RBAC model

## Output
- Modified `configs/create_users.tfvars` or `configs/create_service_users.tfvars` (and `create_role.tfvars` if a new role was added)
- `terraform plan` output for `account_governance/users` or `account_governance/service_users` (and `account_governance/roles` if changed)
- RBAC risk notes for any privilege expansion or ACCOUNTADMIN proximity

## Examples

### Example 1: New human user
User: `$coco-iac-agent-new-role-user add jsmith, jsmith@company.com, ANALYST_ROLE, ANALYST_WH, prod`
Assistant: Reads create_users.tfvars, adds JSMITH entry with must_change_password=true and workspace schema. Runs plan for account_governance/users. Flags any ForceNew.

### Example 2: New service user (TYPE=SERVICE)
User: `$coco-iac-agent-new-role-user add service user ETL_SVC for ETL_ROLE in test, RSA auth`
Assistant: Detects service user → uses `create_service_users.tfvars` + `account_governance/service_users` stack. Validates ETL_ROLE exists. Adds ETL_SVC entry with `rsa_public_key = null` (placeholder), `granted_roles = ["ETL_ROLE"]`. Runs plan for `account_governance/service_users`. Outputs apply command. Reminds user to set RSA key after creation.

### Example 3: New role only
User: `$coco-iac-agent-new-role-user create REPORTING_ROLE in prod, parent SYSADMIN`
Assistant: Reads create_role.tfvars, adds REPORTING_ROLE under SYSADMIN. Runs plan for account_governance/roles. Outputs apply command for user to run.

### Example 4: Legacy service account (snowflake_user)
User: `$coco-iac-agent-new-role-user add user TERRAFORM_CI for CI_ROLE in test, service account`
Assistant: Asks if this is a non-interactive service account → recommends `snowflake_service_user` via `create_service_users.tfvars`. If user insists on `snowflake_user`, adds to `create_users.tfvars` with `create_workspace_schema = false`, flags as legacy pattern.
