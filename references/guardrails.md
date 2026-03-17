# Guardrails

Single source of truth for command format and stopping points.
Behavioral safety rules (NEVER statements) are now enforced via `cortex ctx` rules — persistent across sessions.
Run `cortex ctx rule list` to review all active rules. See `docs/RULES_REFERENCE.md` for the full catalog.

---

## Safety Rules (enforced via cortex ctx rules)

All NEVER rules (Terraform, Git, SQL, secrets) are persisted as `cortex ctx` rules.
They load automatically at session start — no need to re-read this file for behavioral enforcement.

See `docs/RULES_REFERENCE.md` for the complete categorized list.

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
