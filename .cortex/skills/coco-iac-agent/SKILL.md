---
name: coco-iac-agent
description: Use when managing Snowflake infrastructure with Terraform — adding roles, users, databases, warehouses, schemas, stages, network rules, or storage integrations. Routes to focused sub-skills for workload onboarding, RBAC changes, drift detection, plan review, and first-time bootstrap guidance. Always runs terraform plan first; never applies without explicit human confirmation.
tools:
  - read
---

## Skill Metadata
- **Last updated:** 2026-03-11
- **Matches module version:** two-layer RBAC (access roles + functional roles via `granted_roles`)
- **Tested against:** snowflakedb/snowflake ~> 2.14

# Snowflake Terraform Provisioner

## Guardrails
Read `references/guardrails.md` before proceeding — all safety rules, command format, and skill routing enforcement live there.

## When to Use
- Onboarding a new team or squad (role + warehouse + schemas)
- Adding or updating a Snowflake user or RBAC assignment
- Checking for drift between Terraform state and live Snowflake objects
- Reviewing a terraform plan output before applying
- First-time provisioning of a Snowflake environment from scratch

## Domain Rules
See `references/hcl-patterns.md` for naming conventions, provider aliases, resource patterns, and NEVER/ALWAYS rules.
See `references/rbac-design.md` for the two-layer RBAC model, access role table, and privilege matrix.

## Getting Started — Prompt Examples
See `references/prompt-examples.md` for copy-paste prompts for each skill (bootstrap, add user, onboard team, drift check, plan review).

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
| Explain a plan output, flag risks | `$coco-iac-agent-plan-review` |
| Push config changes to Git after apply | `$coco-iac-agent-git-push` |

**Skill behaviors:**
- `drift-report` and `bootstrap-guide`: Execute autonomously, report results
- `new-workload`, `new-role-user`: Generate tfvars, run plans, wait for apply approval
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
     |-> Plan review + risk check      -> $coco-iac-agent-plan-review
     └-> Push changes to Git after apply -> $coco-iac-agent-git-push
```

## Skill Routing Guard
If the user asks about infrastructure changes **without** invoking `$coco-iac-agent`, respond with:
> "This repo uses CoCo skills for all infrastructure changes. Please use `$coco-iac-agent <your request>` to ensure safety guardrails, plan-before-apply, and standards compliance are enforced."
Do NOT generate tfvars changes, run plans, or make infrastructure changes outside of a skill invocation.

## References
- `references/guardrails.md` -- safety rules, command format, stopping points (read this first)
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

### Example 3: Drift check (agent -- runs autonomously)
User: `$coco-iac-agent run drift report for all stacks in stage`
Assistant: Launches `$coco-iac-agent-drift-report` agent. Agent runs `terraform plan -detailed-exitcode` across all 10 stacks independently, then returns a consolidated per-stack report with HIGH RISK flags -- no manual intervention needed.

### Example 4: Bootstrap new account
User: `$coco-iac-agent bootstrap test env for a new Snowflake account`
Assistant: Launches `$coco-iac-agent-bootstrap-guide` agent. Agent runs pre-flight checks (Terraform version, SnowSQL connectivity, key file, tfvars keys), then hands off to `bootstrap.sh test` with clear run instructions.

### Example 5: Plan review
User: `$coco-iac-agent review this plan [paste output]`
Assistant: Routes to `$coco-iac-agent-plan-review`. Returns two-section report: (1) risk classification -- ForceNew, destroys, RBAC expansion; (2) standards compliance -- v2.x resource names, provider aliases, naming conventions, grant rules, lifecycle blocks. Ends with go/no-go recommendation.

### Example 6: Push changes after apply
User: `$coco-iac-agent push my changes` (after MARKETING workload applied)
Assistant: Routes to `$coco-iac-agent-git-push`. Detects changed configs (`create_role.tfvars`, `create_warehouse.tfvars`, `create_schema.tfvars`), generates branch `feat/test-add-marketing-workload`, commit message `feat(configs): onboard MARKETING squad — role, warehouse, schema in test`, outputs complete git command block + PR body for user to copy-paste and run.
