# CoCo Agent Usage Guide — Snowflake Terraform IaC

How to use the `$coco-iac-agent` skill and agents to manage Snowflake infrastructure.
CoCo handles config generation, planning, and risk review. **You handle `terraform apply`.**

---

## Mental Model

```
CoCo (agent/skill)              You (human)
──────────────────────          ──────────────────────────
Edit configs/*.tfvars           Review the plan output
Run terraform plan              Run terraform apply
Check standards compliance      Confirm it's safe to apply
Flag risks and violations       Make the final call
Run pre-flight checks           Fix any failures CoCo flags
```

CoCo never runs `terraform apply`. Every apply is explicitly yours.

---

## Available Skills and Agents

| Name | Type | What it does |
|---|---|---|
| `$coco-iac-agent` | Skill (router) | Entry point — routes to the right skill or agent |
| `$coco-iac-agent-bootstrap-guide` | **Agent** (non-autonomous) | Pre-flight checks + hands off to bootstrap script, assists with errors |
| `$coco-iac-agent-drift-report` | **Agent** (autonomous) | Runs all 10 plans independently, returns consolidated drift report |
| `$coco-iac-agent-new-workload` | Skill | Onboard a team: role + warehouse + schemas + grants — with NAME PROPOSAL gate |
| `$coco-iac-agent-new-role-user` | Skill | Add a user, create a role, update RBAC — with NAME PROPOSAL gate |
| `$coco-iac-agent-account-objects` | Skill | Resource monitors, network rules, external access integrations — with NAME PROPOSAL gate |
| `$coco-iac-agent-destroy` | Skill | Remove resources safely: checks dependencies + prevent_destroy, runs plan, outputs apply command |
| `$coco-iac-agent-promote-env` | Skill | Promote validated configs from test → stage or prod with correct env suffix transformation |
| `$coco-iac-agent-plan-review` | Skill | Risk classification + standards compliance check + go/no-go |
| `$coco-iac-agent-git-push` | Skill | Generate branch name, commit message, and PR commands after apply |

**Agents** run commands themselves and report back.
**Skills** generate config changes and plan commands for you to run.

You can invoke any directly with `$name` or go through the parent:
```
$coco-iac-agent <describe what you need>
```

---

## Prerequisites — Snowflake Connection

CoCo and the bootstrap script require a working Snowflake connection via Snow CLI.
Create or update `~/.snowflake/connections.toml`:

```toml
[sf_test]
account = "ORGNAME-ACCTNAME"
user = "YOUR_USER"
authenticator = "SNOWFLAKE_JWT"
private_key_path = "/path/to/snowflake_key.p8"
database = "YOUR_DB"
schema = "YOUR_SCHEMA"
warehouse = "YOUR_WH"
role = "SYSADMIN"
```

Verify the connection works:
```bash
snow sql -c sf_test -q "SELECT CURRENT_ACCOUNT(), CURRENT_USER(), CURRENT_ROLE();"
```

> **Note:** Never commit `connections.toml` or private key files. Both should stay in your home directory, outside the repo.

---

## Workflow 1 — Bootstrap a New Snowflake Account

Use this for first-time provisioning of a fresh environment.

### Step 1 — Prepare configs first (no CoCo needed yet)

Before invoking CoCo, manually review and fill in:
```
live/<env>/account.auto.tfvars        ← connection details (org, account, user, key path)
live/<env>/configs/create_role.tfvars
live/<env>/configs/create_database.tfvars
live/<env>/configs/create_users.tfvars
live/<env>/configs/create_warehouse.tfvars
live/<env>/configs/create_resource_monitor.tfvars
live/<env>/configs/create_schema.tfvars
live/<env>/configs/create_network_rules.tfvars
live/<env>/configs/create_storage_integration_s3.tfvars
live/<env>/configs/create_external_access_integrations.tfvars
live/<env>/configs/create_stage_s3.tfvars
```

### Step 2 — Start CoCo from the repo root

```
$coco-iac-agent-bootstrap-guide bootstrap test env — starting from scratch
```

CoCo (agent) will:
1. Run pre-flight checks: Terraform version, SnowSQL connectivity, key file exists, tfvars keys present
2. Report any failures — fix them before continuing
3. Once all checks pass, tell you to run the bootstrap script:

```bash
# macOS / Linux
chmod +x bootstrap/bootstrap.sh
./bootstrap/bootstrap.sh test

# Windows (PowerShell)
.\bootstrap\bootstrap.ps1 -Env test
```

### Step 3 — Run the script, use CoCo alongside

The script walks all 10 stacks in dependency order.
- It shows you the plan.
- It **hard-stops (exit 2)** if the plan contains `# forces replacement`.
- Otherwise it prompts `[y/N]` before each `apply`.

**If you see something in a plan you don't understand:**
```
$coco-iac-agent-bootstrap-guide I'm on stack 3 (users). Here's the plan: [paste]
Is this safe to apply?
```

**If you get an error:**
```
$coco-iac-agent-bootstrap-guide Got this error on stack 6: [paste error]
```

**If you need to resume after stopping:**
```
$coco-iac-agent-bootstrap-guide I've applied stacks 1–5. What's next?
```

### Step 4 — Verify after all 10 stacks

- Log into Snowflake — confirm you auto-land in your workspace schema
- Warehouses visible and auto-suspending
- Network rules visible in `ADMIN_DB.GOVERNANCE`

---

## Workflow 2 — Add a New Team / Workload (Day-2)

Use when onboarding a new squad that needs role + warehouse + schemas.

### Invoke

```
$coco-iac-agent onboard FINANCE squad in test:
  role: FINANCE_ANALYST_ROLE (under SYSADMIN)
  warehouse: FINANCE_WH (XSMALL, auto_suspend 60)
  schemas: ANALYTICS_DB.FINANCE_MART, RAW_DB.FINANCE
  access: read-only on RAW_DB, read-write on ANALYTICS_DB.FINANCE_MART
```

### CoCo does

1. Proposes names (NAME PROPOSAL table) — waits for your approval before touching any file
2. Reads `live/test/configs/create_role.tfvars` — adds `FINANCE_ANALYST_ROLE_TEST` under SYSADMIN
3. Reads `create_warehouse.tfvars` — adds `FINANCE_WH_TEST` with `auto_suspend = 60`, `auto_resume = true`
4. Reads `create_schema.tfvars` — adds the two schemas
5. Runs `terraform plan` for roles → warehouses → schemas stacks in that order
6. Returns plan summaries — flags any `# forces replacement`

### You do

Review each plan. Apply using the safe apply script — **never raw `terraform apply`**:
```bash
bash scripts/stack-apply.sh test account_governance roles
bash scripts/stack-apply.sh test platform warehouses
bash scripts/stack-apply.sh test workloads schemas
```

`stack-apply.sh` validates config files exist, runs a mandatory plan, blocks ForceNew and destroy-only plans, and prompts `[y/N]` before every apply. See [docs/DAY2_WORKFLOW.md](docs/DAY2_WORKFLOW.md) Step 4 for the full safety checks table.

---

## Workflow 3 — Add a User or RBAC Change (Day-2)

### Add a human user

```
$coco-iac-agent add analyst user in test:
  name: jsmith
  email: jsmith@company.com
  role: ANALYST_ROLE
  warehouse: ANALYST_WH
  workspace schema: yes
```

### Add a service account

```
$coco-iac-agent add service account in prod:
  name: ETL_SVC
  role: ETL_ROLE
  warehouse: ETL_WH
  auth: RSA key (key file at keys/etl_svc.pub)
```

### Grant a role to a user

```
$coco-iac-agent grant REPORTING_ROLE to jsmith in prod
```

### CoCo does

- Reads existing `create_users.tfvars`, adds entry with correct format
- Validates: no ACCOUNTADMIN grants, correct naming convention, `must_change_password` for human users
- Runs `terraform plan` for `account_governance/users` (and `account_governance/roles` if a new role was created)
- Flags `login_name` if it changed on an existing user — HIGH RISK

### You do

```bash
bash scripts/stack-apply.sh <env> account_governance users
```

---

## Workflow 4 — Review a Plan Before Applying

Use this before any `terraform apply` — especially for manual plans or plans generated outside a CoCo session.

```
$coco-iac-agent-plan-review [paste your full terraform plan output here]
```

### What you get back

**Section 1 — Risk Classification:**
```
| Resource               | Operation | Risk         | Reason                              |
|------------------------|-----------|--------------|-------------------------------------|
| snowflake_database.X   | replace   | 🔴 HIGH      | forces replacement — destroy+create |
| snowflake_user.JSMITH  | update    | 🟢 LOW       | display_name change, no replacement |
```

**Section 2 — Standards Compliance:**
```
| Check                  | Status    | Finding                                         |
|------------------------|-----------|-------------------------------------------------|
| Provider version       | ✅ PASS   | snowflakedb/snowflake ~> 2.14                   |
| Warehouse auto_suspend | ❌ FAIL   | ETL_WH missing auto_suspend                     |
| Grant blocks per role  | ❌ FAIL   | ANALYST_ROLE has 2 blocks for DATABASE — drift  |
```

**Final recommendation:** ✅ Safe to apply / ⚠ Review before applying / 🔴 Do not apply

### When to always use plan-review

- Before applying any stack that touches databases, warehouses, or roles
- Whenever you see an unexpectedly large plan
- After pulling someone else's config change
- Any time you're unsure

---

## Workflow 5 — Drift Detection

Use when you suspect someone made manual changes to Snowflake outside Terraform.

```
$coco-iac-agent-drift-report run drift report for all stacks in prod
```

The agent runs autonomously — no input needed. It runs `terraform plan -detailed-exitcode` across all 10 stacks and returns:

```
Stack: account_governance/roles     → ✓ OK (exit 0)
Stack: account_governance/users     → ⚠ DRIFT (exit 2) — 1 resource changed
Stack: platform/databases           → ✓ OK (exit 0)
...

🔴 HIGH RISK: users stack — snowflake_user.JSMITH forces replacement
   Reason: login_name attribute changed outside Terraform
   Action: Do not auto-remediate — review manually
```

After the report, you decide:
- Re-apply the drifted stack to bring Snowflake back in sync
- Leave the manual change and update the config to match
- Investigate before doing either

---

## Workflow 6 — Remove Resources

Use when a user leaves, a team is decommissioned, or test resources need cleanup.

```
$coco-iac-agent remove JSMITH user from test
```

```
$coco-iac-agent decommission MARKETING squad from test — role, warehouse, schemas
```

### CoCo does

1. Reads relevant tfvars file(s), locates the entry
2. Checks for `prevent_destroy = true` — blocks if found
3. Checks downstream dependencies (users assigned to a role, `granted_roles` references)
4. Shows the full diff of what will be removed — waits for your confirmation
5. Removes the entries, runs `terraform plan` to confirm only expected destroys
6. Flags any unexpected cascade destroys
7. Outputs apply commands in reverse dependency order

### You do

Review the plan and run each apply command in order:
```bash
bash scripts/stack-apply.sh <env> account_governance users    # if users affected
bash scripts/stack-apply.sh <env> workloads schemas           # if schemas affected
bash scripts/stack-apply.sh <env> platform warehouses         # if warehouse affected
bash scripts/stack-apply.sh <env> account_governance roles    # if roles affected
```

> `stack-apply.sh` will re-run the plan and prompt `[y/N]` before applying each stack.

---

## Workflow 7 — Promote Configs to Production

Use after validating a workload in test and ready to replicate to stage or prod.

```
$coco-iac-agent promote MARKETING workload from test to prod
```

### CoCo does

1. Reads source env tfvars for the named resources
2. Diffs against target env — skips entries that already exist
3. Transforms env suffixes: `MARKETING_ROLE_TEST` → `MARKETING_ROLE` (prod)
4. Asks about warehouse sizing for prod (keep same or scale up)
5. Adds new entries to target env tfvars — never overwrites existing entries
6. Checks Snowflake for pre-existing objects in target env (avoids ForceNew)
7. Runs plans for target env stacks
8. Outputs apply commands for target env

> **Note:** Users are never promoted automatically — credentials are environment-specific. Add users in prod via `$coco-iac-agent-new-role-user`.

### You do

Review plan and run apply commands for the target env:
```bash
bash scripts/stack-apply.sh prod account_governance roles
bash scripts/stack-apply.sh prod platform warehouses
bash scripts/stack-apply.sh prod workloads schemas
```

---

## ForceNew Guardrail

Any plan containing `# forces replacement` on a database, warehouse, or role is HIGH RISK — the resource will be destroyed and recreated, which means data loss for databases and downtime for warehouses.

`stack-apply.sh` blocks these automatically. If you're running plans manually, scan before applying:

```bash
bash scripts/stack-plan.sh <env> <layer> <resource> --run 2>&1 | tee plan.out
bash scripts/scan-forcenew.sh plan.out   # exit 2 = stop, do not apply
```

If CoCo flags a ForceNew, ask it to explain before proceeding:
```
$coco-iac-agent explain this forces replacement on ANALYTICS_DB: [paste plan section]
```

---

## Database Rename (Special Workflow)

Database renames are not supported by the Snowflake Terraform provider — changing `name` forces replacement (destroy + recreate), which means all schemas, tables, and data in the database are lost.

Use the SnowSQL escape hatch instead:

```
live/<env>/platform/database_rename/README.md
live/<env>/platform/database_rename/RENAMING_LIMITATIONS.md
```

The escape hatch stack uses SnowSQL to rename the database in Snowflake first, then reconciles Terraform state without recreating the resource.

---

## Troubleshooting

**Destroy-only plan (0 adds, N destroys)**
Config tfvars not loaded — `-var-file` flag missing or file is empty. Verify both flags are passed: `account.auto.tfvars` and `configs/<resource>.tfvars`. Never apply a destroy-only plan without understanding why.

**`# forces replacement` on database / warehouse / role**
Stop. Do not apply. Use `$coco-iac-agent-plan-review` to understand the cause. Usually triggered by a name change or unsupported in-place attribute change.

**SnowSQL not found**
Install SnowSQL and ensure it is on `PATH`. Required for stacks 6 (storage integrations) and 9 (external access integrations). Verify: `snowsql -v`.

**Snow CLI connection fails**
Test with `snow sql -c <connection> -q "SELECT CURRENT_USER();"`. Check `~/.snowflake/connections.toml` — account format must be `ORGNAME-ACCTNAME`.

**Auth failures (Terraform)**
Verify `private_key_path` in `account.auto.tfvars` points to the correct `.p8` file. The public key must be attached to the provisioning user in Snowflake: `ALTER USER <user> SET RSA_PUBLIC_KEY='<pub key content>';`.

**Provider errors / unexpected diffs on first apply**
Some grant resources show a plan on first apply — this is expected behaviour in the v2.x provider. Apply once; subsequent plans will show no changes.

**Remote state errors**
Confirm S3 bucket exists, IAM permissions are correct, and state locking (DynamoDB) is configured before re-running `terraform init -backend-config=...`.

**Debug mode**
```bash
TF_LOG=DEBUG terraform plan -var-file=../../account.auto.tfvars -var-file=../../configs/<resource>.tfvars
```

---

## Optimal Usage Tips

### Give CoCo complete context upfront

More specific = better output:
```
# Less useful
$coco-iac-agent add a user

# More useful
$coco-iac-agent add analyst user: name=jsmith, email=jsmith@co.com,
  role=ANALYST_ROLE, warehouse=ANALYST_WH, workspace=yes, env=test
```

### Always paste errors back to CoCo

Don't try to debug Terraform provider errors alone:
```
$coco-iac-agent got this error applying the users stack: [paste full error]
```

### One stack at a time for day-2 changes

Don't re-apply all 10 stacks when you only changed one config file.
CoCo routes to the right stack — trust it.

### Use plan-review on any unfamiliar plan

If a plan shows more changes than you expected, always review it:
```
$coco-iac-agent-plan-review this plan shows 8 resources changing but I only added 1 user: [paste]
```

### For drift: run report before a big change

Before onboarding a new team or making bulk RBAC changes, run a drift report first.
Ensures you're starting from a clean state.

---

## Quick Reference — Prompt Patterns

```
# Bootstrap
$coco-iac-agent bootstrap <env> env — starting from scratch

# New workload
$coco-iac-agent onboard <TEAM> squad in <env>:
  role: <TEAM>_ROLE, warehouse: <TEAM>_WH (XSMALL), schemas: [list], access: [read/write]

# New user
$coco-iac-agent add user: name=<name>, email=<email>, role=<ROLE>, warehouse=<WH>, env=<env>

# Account objects (resource monitors, network rules, EAIs)
$coco-iac-agent add a monthly 500-credit resource monitor in <env>
$coco-iac-agent add PyPI egress network rule and wire it to an EAI in <env>

# Remove a single resource
$coco-iac-agent remove <RESOURCE_NAME> <type> from <env>

# Remove full workload
$coco-iac-agent decommission <TEAM> squad from <env> — role, warehouse, schemas

# Promote to prod
$coco-iac-agent promote <TEAM> workload from test to prod

# Plan review (paste plan after)
$coco-iac-agent-plan-review [plan output]

# Drift check
$coco-iac-agent-drift-report run drift report for all stacks in <env>

# Error help
$coco-iac-agent got this error on <stack>: [paste error]

# ForceNew question
$coco-iac-agent explain this forces replacement on <resource>: [paste plan section]
```

---

## File Locations

| What | Where |
|---|---|
| Connection credentials | `live/<env>/account.auto.tfvars` |
| Object declarations | `live/<env>/configs/*.tfvars` |
| Bootstrap script | `bootstrap/bootstrap.sh` (macOS/Linux), `bootstrap/bootstrap.ps1` (Windows) |
| Stack order and dependencies | `references/stack-mapping.md` |
| HCL copy-paste patterns | `references/hcl-patterns.md` |
| Raw Terraform commands (no scripts) | `docs/TERRAFORM_COMMANDS.md` |
