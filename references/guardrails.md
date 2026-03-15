# Guardrails

Single source of truth for all safety rules. All skills read this file — do not duplicate these rules in individual SKILL.md files.

## Terraform Safety — ABSOLUTE RULES

- **NEVER execute `scripts/stack-apply.sh`** — output the command for the user to run manually
- **NEVER run `terraform apply` directly**
- **NEVER run `terraform destroy`** — output the manual command for the user to run; do not execute it
- **NEVER run raw `terraform plan`** — always use `scripts/stack-plan.sh`
- For plan: run `scripts/stack-plan.sh` yourself and show the output
- For apply or destroy: output the command, stop, and wait for the user to confirm and run it
- Never print or read private key file contents
- `# forces replacement` on database / warehouse / role = HIGH RISK — pause, explain, wait for explicit instruction

## Git Safety — ABSOLUTE RULES

- **NEVER execute `git commit`, `git push`, or `gh pr create`** — output commands for user to run
- **NEVER push directly to `main`** — always branch + PR
- **NEVER run `git add .`** — stage specific files only (avoids committing secrets, state files)
- For any commit/push/PR workflow: output the exact commands as a code block, stop, user runs them
- This applies to ALL skills — any change that needs to be committed follows this pattern

**Example — correct behavior:**
```
To commit and push these changes:

\`\`\`bash
git checkout -b feat/test-add-marketing-workload
git add live/test/configs/create_role.tfvars
git commit -m "feat(configs): add MARKETING_ROLE in test"
git push -u origin feat/test-add-marketing-workload
gh pr create --title "feat(configs): add MARKETING_ROLE" --body "..."
\`\`\`
```

**NEVER run git commit/push yourself, even if the user says "yes" or "proceed".**

## SQL Safety — ABSOLUTE RULES

- **NEVER execute destructive SQL commands** — output them for the user to run manually
- Destructive SQL includes: `DROP`, `TRUNCATE`, `DELETE`, `CREATE OR REPLACE`, `ALTER ... DROP`, `REVOKE`
- **Read-only SQL is allowed**: `SHOW`, `DESCRIBE`, `SELECT`, `EXPLAIN`
- When drift report suggests removing unmanaged objects, **output the DROP commands** — do not execute them
- When any skill suggests cleanup SQL, **output as a code block** — user copies and runs
- This applies to ALL execution methods: `snow sql`, `snowsql`, `snowflake_sql_execute`, or any SQL tool

**Example — correct behavior:**
```
Unmanaged role SALES_ROLE detected. To remove it, run:

\`\`\`sql
DROP ROLE SALES_ROLE;
\`\`\`
```

**NEVER run DROP/TRUNCATE/DELETE yourself, even if the user says "yes" or "proceed".**

## Command Format

```bash
# Plan (CoCo runs this and shows output):
bash scripts/stack-plan.sh <env> <layer> <stack> --run

# Apply (output for user to run — CoCo does NOT execute this):
bash scripts/stack-apply.sh <env> <layer> <stack>
```

**NEVER execute `stack-apply.sh`.** Output it as a command block for the user to copy and run.

## Skill Routing

Any request involving infrastructure changes (roles, users, databases, warehouses, schemas, grants, drift, plan review) must be handled via the `$coco-iac-agent` skill.

If the user asks directly without invoking `$coco-iac-agent`, respond with:
> "This repo uses CoCo skills for all infrastructure changes. Please use `$coco-iac-agent <your request>` to ensure safety guardrails, plan-before-apply, and standards compliance are enforced."

Do NOT generate tfvars changes, run plans, or make infrastructure changes outside of a skill invocation.

## Stopping Points

- After any `terraform plan` output — present diff, wait for explicit approval before next step
- Before each `stack-apply.sh` — confirm explicitly with user
- If `# forces replacement` on database / warehouse / role — stop, explain risk, wait
- Before switching environments — confirm scope with user first

**Resume:** On "looks good", "proceed", or "yes" — continue to next step.
