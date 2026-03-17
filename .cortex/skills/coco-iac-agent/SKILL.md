---
name: coco-iac-agent
description: Use when managing Snowflake infrastructure with Terraform — adding roles, users, databases, warehouses, schemas, resource monitors, network rules, external access integrations, or storage integrations. Routes to focused sub-skills for workload onboarding, RBAC changes, account objects, drift detection, plan review, and first-time bootstrap guidance. Always runs terraform plan first; never applies without explicit human confirmation.
tools:
  - read
---

## Skill Metadata
- **Last updated:** 2026-03-11
- **Matches module version:** two-layer RBAC (access roles + functional roles via `granted_roles`)
- **Tested against:** snowflakedb/snowflake ~> 2.14

# Snowflake Terraform Provisioner

## Guardrails
Safety, naming, RBAC, and workflow rules are enforced via `cortex ctx` rules (persistent across sessions).
Run `cortex ctx rule list` to review active rules. See `docs/RULES_REFERENCE.md` for the full catalog.

## When to Use
- Onboarding a new team or squad (role + warehouse + schemas)
- Adding or updating a Snowflake user or RBAC assignment
- Removing one or more resources (user, role, warehouse, schema, full workload)
- Promoting validated configs from test → stage or prod
- Checking for drift between Terraform state and live Snowflake objects
- Reviewing a terraform plan output before applying
- First-time provisioning of a Snowflake environment from scratch

## Domain Rules
See `references/hcl-patterns.md` for HCL templates and `references/rbac-design.md` for the two-layer RBAC model.
Behavioral rules (naming, safety, RBAC constraints) are in `cortex ctx` rules.

## Mental Model
- CoCo generates, plans, and shows output. Human runs apply.
- One stack at a time for day-2 changes.
- Any `# forces replacement` on a database, warehouse, or role = stop and explain.

## Routing
Route every request to the appropriate skill:

| Request type | Invoke |
|---|---|
| First-time env setup, prerequisites, stack walkthrough | `$coco-iac-agent-bootstrap-guide` |
| Find drift (manual changes outside Terraform) | `$coco-iac-agent-drift-report` |
| New team/squad (role + warehouse + schemas) | `$coco-iac-agent-new-workload` |
| Add a user, update RBAC, role grants | `$coco-iac-agent-new-role-user` |
| Resource monitors, network rules, external access integrations | `$coco-iac-agent-account-objects` |
| Remove a user, role, warehouse, schema, or full workload | `$coco-iac-agent-destroy` |
| Promote configs from test → stage or prod | `$coco-iac-agent-promote-env` |
| Explain a plan output, flag risks | `$coco-iac-agent-plan-review` |
| Push config changes to Git after apply | `$coco-iac-agent-git-push` |

**Skill behaviors:**
- `drift-report` and `bootstrap-guide`: Execute autonomously, report results
- `new-workload`, `new-role-user`, `account-objects`: Generate tfvars, run plans, wait for apply approval
- `destroy`: Safety-checks dependencies + prevent_destroy, removes tfvars entries, runs plan, outputs apply command — never executes apply
- `promote-env`: Reads source env, transforms names (env suffix), diffs against target, runs plan for target, outputs apply command
- `plan-review`: Analyze plan output, flag risks, recommend go/no-go
- `git-push`: Detects changed configs, generates branch name + commit message, outputs git commands — user runs them

## Workflow

```
User request
     |
Intent detection
     |
     |-> Bootstrap / first-time setup  -> $coco-iac-agent-bootstrap-guide
     |-> Drift check across all stacks -> $coco-iac-agent-drift-report
     |-> New team / workload           -> $coco-iac-agent-new-workload
     |-> Add user / RBAC change        -> $coco-iac-agent-new-role-user
     |-> Resource monitors / network rules / EAIs -> $coco-iac-agent-account-objects
     |-> Remove resource(s)            -> $coco-iac-agent-destroy
     |-> Promote test → stage / prod   -> $coco-iac-agent-promote-env
     |-> Plan review + risk check      -> $coco-iac-agent-plan-review
     └-> Push changes to Git after apply -> $coco-iac-agent-git-push
```

## Skill Routing Guard
If the user asks about infrastructure changes **without** invoking `$coco-iac-agent`, respond with:
> "This repo uses CoCo skills for all infrastructure changes. Please use `$coco-iac-agent <your request>` to ensure safety guardrails, plan-before-apply, and standards compliance are enforced."
Do NOT generate tfvars changes, run plans, or make infrastructure changes outside of a skill invocation.

## References
- `references/guardrails.md` -- safety rules, command format, stopping points (read this first)
- `references/naming-conventions.md` -- object naming patterns, NAME PROPOSAL format, conflict detection
- `references/stack-mapping.md` -- execution order, provider aliases, env naming
- `references/hcl-patterns.md` -- copy-paste HCL blocks for every resource type
- `references/workflow.md` -- execution contract and guardrails
- `references/rbac-design.md` -- two-layer RBAC design, access role table, privilege matrix

## Examples

### Example 1: New workload onboarding
User: `$coco-iac-agent onboard MARKETING squad in test with read access to analytics mart`
Assistant: Routes to `$coco-iac-agent-new-workload`, reads existing tfvars configs, generates `MARKETING_READ` + `MARKETING_WRITE` access roles and `MARKETING_ROLE` functional role with `granted_roles = ["ANALYTICS_READ", "MARKETING_WRITE"]`, adds `MARKETING_WH_TEST` + schemas, runs plans for roles -> warehouses -> schemas stacks in order.

### Example 2: Add a user
User: `$coco-iac-agent add user jsmith, email jsmith@company.com, ANALYST_ROLE, prod`
Assistant: Routes to `$coco-iac-agent-new-role-user`, validates role hierarchy, generates create_users.tfvars entry, runs plan for account_governance/users.

### Example 3: Drift check
User: `$coco-iac-agent run drift report for all stacks in stage`
Assistant: Routes to `$coco-iac-agent-drift-report`. Runs `terraform plan -detailed-exitcode` across all 10 stacks autonomously, then returns a consolidated per-stack report with HIGH RISK flags — no manual intervention needed.

### Example 4: Bootstrap new account
User: `$coco-iac-agent bootstrap test env for a new Snowflake account`
Assistant: Routes to `$coco-iac-agent-bootstrap-guide`. Runs pre-flight checks (Terraform version, SnowSQL connectivity, key file, tfvars keys), then hands off to `bootstrap.sh test` with clear run instructions.

### Example 5: Plan review
User: `$coco-iac-agent review this plan [paste output]`
Assistant: Routes to `$coco-iac-agent-plan-review`. Returns two-section report: (1) risk classification -- ForceNew, destroys, RBAC expansion; (2) standards compliance -- v2.x resource names, provider aliases, naming conventions, grant rules, lifecycle blocks. Ends with go/no-go recommendation.

### Example 6: Push changes after apply
User: `$coco-iac-agent push my changes` (after MARKETING workload applied)
Assistant: Routes to `$coco-iac-agent-git-push`. Detects changed configs (`create_role.tfvars`, `create_warehouse.tfvars`, `create_schema.tfvars`), generates branch `feat/test-add-marketing-workload`, commit message `feat(configs): onboard MARKETING squad — role, warehouse, schema in test`, outputs complete git command block + PR body for user to copy-paste and run.

### Example 7: Remove a resource
User: `$coco-iac-agent remove MARKETING warehouse from test`
Assistant: Routes to `$coco-iac-agent-destroy`. Reads `create_warehouse.tfvars`, finds `MARKETING_WH_TEST`. No `prevent_destroy`. Shows diff (1 entry). On user confirmation, removes entry, runs plan for `platform/warehouses` showing `1 to destroy`, outputs `bash scripts/stack-apply.sh test platform warehouses`.

### Example 8: Promote to prod
User: `$coco-iac-agent promote MARKETING workload from test to prod`
Assistant: Routes to `$coco-iac-agent-promote-env`. Reads test + prod tfvars. Strips `_TEST` suffix from all MARKETING entries. Diffs against prod — `ANALYTICS_READ` already exists, skipped. Shows promotion diff for roles, warehouse, schemas. Asks about warehouse sizing. On confirmation, edits prod tfvars. Runs plans for roles → warehouses → schemas. Outputs 3 apply commands.

### Example 9: Add network rule and EAI
User: `$coco-iac-agent add PyPI egress network rule and external access integration in prod`
Assistant: Routes to `$coco-iac-agent-account-objects`. Verifies ADMIN_DB.GOVERNANCE schema exists. Adds `PYPI_NETWORK_RULE` (HOST_PORT/EGRESS) to `create_network_rules.tfvars` and `PYPI_ACCESS_INTEGRATION` referencing it to `create_external_access_integrations.tfvars`. Runs plan for `platform/network_rules` then `platform/external_access_integrations`. Waits for approval between stacks. Outputs apply commands in dependency order.
