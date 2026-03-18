# Snowflake Terraform IaC Agent

Provider: `snowflakedb/snowflake ~> 2.14` (v2.x — NOT Snowflake-Labs, NOT 0.x)

## Skill-First Architecture

**ALL infrastructure requests MUST route through skills.** This repo uses a skill system for safety, consistency, and auditability.

Entry point: `$coco-iac-agent` → routes to appropriate sub-skill

### Available Skills

| Skill | Purpose |
|-------|---------|
| `$coco-iac-agent` | Router — detects intent, delegates to sub-skill |
| `$coco-iac-agent-bootstrap-guide` | First-time env setup, prerequisites, stack walkthrough |
| `$coco-iac-agent-drift-report` | Detect drift between Terraform state and live Snowflake |
| `$coco-iac-agent-new-workload` | Onboard team/squad (role + warehouse + schemas) |
| `$coco-iac-agent-new-role-user` | Add user, RBAC changes, role grants |
| `$coco-iac-agent-account-objects` | Resource monitors, network rules, external access integrations |
| `$coco-iac-agent-destroy` | Remove resources (safety-checked, never auto-applies) |
| `$coco-iac-agent-promote-env` | Promote configs test → stage → prod |
| `$coco-iac-agent-plan-review` | Analyze plan output, flag risks, go/no-go |
| `$coco-iac-agent-git-push` | Generate branch + commit + PR after apply |

### Skill Routing Guard

If asked about infrastructure changes without `$coco-iac-agent`:
> "This repo uses CoCo skills for all infrastructure changes. Please use `$coco-iac-agent <your request>` to ensure safety guardrails, plan-before-apply, and standards compliance are enforced."

## Terraform Safety — ABSOLUTE RULES

- **NEVER** execute `scripts/stack-apply.sh` — output command for user
- **NEVER** run `terraform apply` or `terraform destroy` directly
- **NEVER** run raw `terraform plan` — use `scripts/stack-plan.sh`
- **NEVER** hardcode credentials, account locators, or private key content
- For plan: run `scripts/stack-plan.sh` and show output
- For apply/destroy: output command, stop, wait for user

## Git Safety — ABSOLUTE RULES

- **NEVER** execute `git commit`, `git push`, or `gh pr create` — output commands for user
- **NEVER** push directly to `main` — always branch + PR
- **NEVER** run `git add .` — stage specific files only
- For commit/push/PR: output exact commands as code block, user runs them

**When user asks to commit/push/PR:** Direct them to use `$coco-iac-agent-git-push` for standardized branch naming, commit messages, and PR creation.

## SQL Safety — ABSOLUTE RULES

- **NEVER** execute destructive SQL: `DROP`, `TRUNCATE`, `DELETE`, `CREATE OR REPLACE`, `REVOKE`
- Read-only SQL allowed: `SHOW`, `DESCRIBE`, `SELECT`, `EXPLAIN`
- Output destructive SQL as code block for user to run

## Provider Aliases

| Alias | Manages |
|-------|---------|
| `secadmin` | roles, users, network rules |
| `sysadmin` | databases, warehouses, schemas, stages |
| `accountadmin` | resource monitors, storage/external access integrations |

## Role Hierarchy

```
ACCOUNTADMIN  (never reference in Terraform)
  └── SECURITYADMIN  (role memberships, user assignments)
        └── SYSADMIN  (databases, warehouses, schemas)
              └── custom functional roles (<TEAM>_ROLE)
```

## Naming Conventions

- Snowflake objects: `UPPERCASE`
- Terraform resource labels: `snake_case`
- Roles: `<TEAM>_ROLE` | Warehouses: `<TEAM>_WH` | Databases: `<PURPOSE>_DB`
- Env suffix: `_TEST`, `_STAGE`, none for prod

## NEVER Use (Deprecated v0.x Resources)

| Wrong | Correct |
|-------|---------|
| `snowflake_role` | `snowflake_account_role` |
| `snowflake_grant_privileges_to_role` | `snowflake_grant_privileges_to_account_role` |
| `snowflake_grant_role` | `snowflake_grant_account_role` |

## ALWAYS

- Flag `# forces replacement` on database/warehouse/role as HIGH RISK
- One grant block per role per object type (prevents drift)
- `auto_suspend` + `auto_resume` on every warehouse
- `prevent_destroy = true` on databases and critical roles

## References

All detailed documentation lives in `references/`:
- `guardrails.md` — safety rules, command format, stopping points
- `naming-conventions.md` — object naming, NAME PROPOSAL format
- `stack-mapping.md` — execution order, provider aliases, env naming
- `hcl-patterns.md` — copy-paste HCL blocks for every resource type
- `rbac-design.md` — two-layer RBAC model, access role table, privilege matrix

## Repo Structure

```
live/
  test/           # Test environment stacks
  prod/           # Production environment stacks
modules/          # Reusable Terraform modules
scripts/          # stack-plan.sh, stack-apply.sh, bootstrap.sh
references/       # Domain knowledge (guardrails, patterns, RBAC)
.cortex/skills/   # CoCo skill definitions
```
