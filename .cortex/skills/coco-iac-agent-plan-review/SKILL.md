---
name: coco-iac-agent-plan-review
description: Use when you need a plain-English explanation of a terraform plan output, a risk classification, and a standards compliance check before human-gated apply. Reviews every change against risk levels AND v2.x provider conventions for this repo. Returns a two-section report: risks first, then standards compliance, with a final go/no-go recommendation.
tools:
  - read
  - bash
---

## Skill Metadata
- **Last updated:** 2026-03-26
- **Matches module version:** two-layer RBAC (access roles + functional roles via `granted_roles`)
- **Tested against:** snowflakedb/snowflake ~> 2.14

# Plan Review

## When to Use
- Before applying any stack (CoCo outputs `stack-apply.sh` command; user runs it — never raw `terraform apply`)
- When a plan output contains changes you don't fully understand
- When you want to verify both safety and standards compliance before applying
- After a drift report surfaces unexpected changes

## Guardrails
Safety, naming, RBAC, and workflow rules are enforced via `cortex ctx` rules.
Run `cortex ctx rule list` to review. See `docs/RULES_REFERENCE.md` for the full catalog.

## Output
- **Section 1:** Risk classification table — resource, operation, risk level (🔴/🟡/🟢), reason
- **Section 2:** Standards compliance table — check, ✅ PASS / ❌ FAIL / ⚠ WARN, finding
- **Final:** One of: ✅ Safe to apply / ⚠ Review before applying / 🔴 Do not apply

## Goal
Produce a two-section review:
1. **Risk classification** — what operations are happening and how dangerous they are
2. **Standards compliance** — whether the plan follows v2.x provider conventions for this repo

Finish with a single go/no-go recommendation.

---

## Section 1 — Risk Classification

Parse the plan for `create`, `update`, `destroy`, `replace` operations.
Classify each change:

| Risk | Trigger |
|---|---|
| 🔴 HIGH | `# forces replacement` on database, warehouse, or role |
| 🔴 HIGH | Any `destroy` on database, warehouse, or role |
| 🔴 HIGH | `snowflake_user.login_name` change on an existing user |
| 🔴 HIGH | `snowflake_schema.with_managed_access` change |
| 🔴 HIGH | `snowflake_network_policy` removal when assigned to account or users — can lock everyone out |
| 🟡 MEDIUM | RBAC changes — new grants, role membership, privilege expansion |
| 🟡 MEDIUM | Schema `# forces replacement` |
| 🟡 MEDIUM | Any grant that adds ACCOUNTADMIN to a functional role |
| 🟡 MEDIUM | `snowflake_account_parameter` change — affects account-wide behavior |
| 🟢 LOW | User attribute updates without replacement |
| 🟢 LOW | New creates for schema, stage, network rule, network policy, service user with no replacement |

**Output format for this section:**

```
### Risk Classification

| Resource | Operation | Risk | Reason |
|---|---|---|---|
| snowflake_database.ANALYTICS_DB | replace | 🔴 HIGH | forces replacement — destroy + recreate |
| snowflake_user.JSMITH | update | 🟢 LOW | display_name change, no replacement |

```

---

## Section 2 — Standards Compliance

Check every resource in the plan against project conventions.
Read `references/hcl-patterns.md` for the authoritative patterns.

### Provider & Version
- [ ] Provider is `snowflakedb/snowflake ~> 2.14` — not `Snowflake-Labs`, not `0.x`
- [ ] `required_version = ">= 1.5"` in terraform block

### Provider Alias Ownership
- [ ] Roles, users, and service users use `provider = snowflake.secadmin`
- [ ] Databases, warehouses, schemas, stages use `provider = snowflake.sysadmin`
- [ ] Resource monitors, storage integrations, external access, network policies, account parameters use `provider = snowflake.accountadmin`

### Resource Names (v2.x — deprecated names cause drift or errors)
- [ ] Roles use `snowflake_account_role` — not `snowflake_role`
- [ ] Privilege grants use `snowflake_grant_privileges_to_account_role` — not `snowflake_grant_privileges_to_role`
- [ ] Role assignments use `snowflake_grant_account_role` — not `snowflake_grant_role`
- [ ] Service accounts use `snowflake_service_user` — not `snowflake_user` with RSA key (legacy pattern)

### Naming Conventions
- [ ] All Snowflake object names UPPERCASE (roles, warehouses, databases, schemas, users)
- [ ] Functional roles follow `<TEAM>_ROLE` pattern (e.g. `ENGINEER_ROLE`, `ANALYST_ROLE`)
- [ ] Access roles follow `<LAYER>_<PERMISSION>` pattern (e.g. `RAW_READ`, `ANALYTICS_WRITE`)
- [ ] Warehouses follow `<TEAM>_WH` pattern
- [ ] Databases follow `<PURPOSE>_DB` pattern
- [ ] Env suffix applied: `_TEST` in test, `_STAGE` in stage, none in prod

### RBAC Two-Layer Model
- [ ] Access roles are **not** assigned directly to users (`snowflake_grant_account_role` target must be a functional role, not an access role)
- [ ] Functional roles compose access roles via `snowflake_grant_account_role.granted_roles` — not via direct `snowflake_grant_privileges_to_account_role` on the functional role itself

### Warehouses
- [ ] `auto_suspend` is set (default should be 60s or less)
- [ ] `auto_resume = true` is set
- [ ] Provider alias is `snowflake.sysadmin`

### Databases and Critical Roles
- [ ] `lifecycle { prevent_destroy = true }` on all databases
- [ ] `lifecycle { prevent_destroy = true }` on critical roles

### Grant Rules (most common drift source)
- [ ] Only one `snowflake_grant_privileges_to_account_role` block per role per object type
  - Multiple blocks for same role + object type = perpetual drift
- [ ] No grant of ACCOUNTADMIN to any functional or service role
- [ ] Role hierarchy: all functional roles granted to SYSADMIN (never directly to ACCOUNTADMIN)

### Users
- [ ] Human users: `must_change_password = true` if using password auth
- [ ] Service accounts: `rsa_public_key` uses `file()` reference — never hardcoded key content
- [ ] `login_name` not changed on any existing user (ForceNew — HIGH RISK)
- [ ] Non-interactive service accounts use `snowflake_service_user` resource — not `snowflake_user` with RSA key
- [ ] `snowflake_service_user` has no `password` attribute set (TYPE=SERVICE enforces key-pair only)

### Network Policies
- [ ] `snowflake_network_policy` uses `provider = snowflake.accountadmin`
- [ ] Removal of existing policy: check if assigned to account or users — 🔴 HIGH RISK if so

### Account Parameters
- [ ] `snowflake_account_parameter` uses `provider = snowflake.accountadmin`
- [ ] Values are always strings (even for numeric parameters)

**Output format for this section:**

```
### Standards Compliance

| Check | Status | Finding |
|---|---|---|
| Provider version | ✅ PASS | snowflakedb/snowflake ~> 2.14 |
| Role resource name | ✅ PASS | snowflake_account_role used correctly |
| Warehouse auto_suspend | ❌ FAIL | ETL_WH missing auto_suspend |
| Grant blocks per role | ❌ FAIL | ANALYST_ROLE has 2 blocks for DATABASE — will cause drift |
| prevent_destroy on DB | ⚠ WARN | Not visible in plan — confirm in main.tf |
```

Mark `⚠ WARN` when the issue can't be confirmed from plan output alone (e.g., `prevent_destroy`
lives in the .tf file, not the plan). Flag it and tell the user where to verify.

---

## Final Recommendation

After both sections, state one of:

- **✅ Safe to apply** — all LOW risk, no standards violations
- **⚠ Review before applying** — list specific items needing human judgment
- **🔴 Do not apply** — HIGH RISK replacement or critical standards violation detected

---

## Examples

### Example 1: Clean plan
User: `$coco-iac-agent-plan-review [plan creating 2 users and 1 schema]`
Assistant:
- Section 1: All LOW (new creates, no replacements)
- Section 2: All PASS (correct resource names, secadmin for users, naming conventions met)
- Recommendation: ✅ Safe to apply

### Example 2: ForceNew on database
User: `$coco-iac-agent-plan-review [plan showing ANALYTICS_DB forces replacement]`
Assistant:
- Section 1: 🔴 HIGH — ANALYTICS_DB destroy + recreate
- Section 2: Runs checks on remaining resources
- Recommendation: 🔴 Do not apply — ANALYTICS_DB will be destroyed. Investigate what attribute changed (likely `name` or `data_retention_time_in_days` type mismatch).

### Example 3: Standards violation
User: `$coco-iac-agent-plan-review [plan with snowflake_role instead of snowflake_account_role]`
Assistant:
- Section 1: LOW risk (new role create, no replacement)
- Section 2: ❌ FAIL — `snowflake_role` is deprecated in v2.x. Must use `snowflake_account_role`. This will cause provider errors or unexpected behavior.
- Recommendation: ⚠ Review before applying — fix resource type before applying.

### Example 4: Duplicate grant blocks
User: `$coco-iac-agent-plan-review [plan with 2 grant blocks for ANALYST_ROLE on ANALYTICS_DB]`
Assistant:
- Section 1: 🟡 MEDIUM — RBAC change
- Section 2: ❌ FAIL — two `snowflake_grant_privileges_to_account_role` blocks for ANALYST_ROLE on DATABASE. This will cause perpetual drift — every plan will show changes.
- Recommendation: ⚠ Review before applying — consolidate into one grant block with all required privileges.
