---
name: coco-iac-agent-git-push
description: Use after a Snowflake infrastructure change (new workload, new user/role, config update) has been applied. Detects which config files changed, generates a branch name and commit message from context, and outputs the exact git commands to push changes and open a PR. Never pushes directly — user runs the commands.
tools:
  - bash
  - read
---

## Skill Metadata
- **Last updated:** 2026-03-11
- **Matches module version:** two-layer RBAC (access roles + functional roles via `granted_roles`)
- **Tested against:** snowflakedb/snowflake ~> 2.14

# Git Push

## When to Use
- After `$coco-iac-agent-new-workload` or `$coco-iac-agent-new-role-user` completes and the user confirms apply succeeded
- After any manual config change to `live/<env>/configs/*.tfvars`
- When the user says "push changes", "commit this", "save to git", "open a PR"

## Goal
Detect changed config files, derive a meaningful branch name and commit message from what was provisioned, and output the exact git commands — ready to copy-paste. The user runs the commands; this skill never pushes.

## Steps

### 1. Detect changes
Run:
```bash
git status --short
git diff --name-only
```
Identify which `live/<env>/configs/*.tfvars` files changed. This determines scope.

### 2. Derive context
From the changed files and the current session (what was provisioned), extract:
- **Environment** — `test`, `stage`, or `prod` (from the file path)
- **Resource type** — roles, users, warehouses, schemas, etc.
- **Team/workload name** — from the tfvars keys that were added/changed
- **Operation** — `add`, `update`, `remove`

### 3. Generate branch name
Pattern: `<type>/<env>-<operation>-<team-or-resource>`

Examples:
| What changed | Branch name |
|---|---|
| Added MARKETING squad (roles + warehouse + schemas) in test | `feat/test-add-marketing-workload` |
| Added user JSMITH in prod | `feat/prod-add-jsmith-user` |
| Updated ANALYST_WH size in test | `fix/test-update-analyst-wh` |
| Added FINANCE_READ access role in prod | `feat/prod-add-finance-read-role` |
| Config-only cleanup, no new resources | `chore/<env>-config-cleanup` |

### 4. Generate commit message
Pattern: `<type>(<scope>): <what> in <env>`

Examples:
| Change | Commit message |
|---|---|
| New MARKETING squad | `feat(configs): onboard MARKETING squad — role, warehouse, schema in test` |
| New user JSMITH | `feat(configs): add JSMITH user with ANALYST_ROLE in prod` |
| Warehouse size update | `fix(configs): update ANALYST_WH to SMALL in test` |
| New access role | `feat(configs): add FINANCE_READ access role in prod` |

Keep the message under 72 characters for the subject line. Put detail in the body if needed.

### 5. Output git commands

Output this exact block (filled in with real values):

```bash
# 1. Ensure you are on latest main
git checkout main
git pull origin main

# 2. Create branch
git checkout -b <branch-name>

# 3. Stage only the changed config files
git add <file1> <file2> ...

# 4. Commit
git commit -m "<subject line>

<optional body with bullet points of what was added>"

# 5. Push branch
git push -u origin <branch-name>

# 6. Open PR
gh pr create --title "<same as commit subject>" --body "$(cat <<'EOF'
## What
- <bullet: resource added/changed>
- <bullet: env>

## Applied
- [ ] terraform apply confirmed by user

## Checklist
- [ ] Plan reviewed before apply
- [ ] No ForceNew on databases or roles
- [ ] Branch will be deleted after merge
EOF
)"
```

### 6. Remind on merge
After outputting commands, add:

> **After the PR is merged:**
> ```bash
> git checkout main
> git pull origin main
> git branch -d <branch-name>
> ```

## Rules
- **Never push directly to `main`** — always branch + PR
- **Stage specific files** — never `git add .` blindly (avoids committing `.terraform/`, state files, or secrets)
- **One logical change per branch** — if multiple workloads changed in one session, split into separate branches
- **Never force push** — the initial repo setup was a one-time exception
- If `git status` shows unexpected files (e.g. `.terraform/`, `*.tfstate`, `*.pem`), flag them and do NOT include in `git add`

## Constraints
- This skill outputs commands only — it does not run `git push`, `git commit`, or `gh pr create`
- If the user has not confirmed apply, remind them: "Confirm the apply completed before pushing config changes to Git"
- If no config files changed (`git status` clean), respond: "Nothing to commit — working tree is clean"

## Examples

### Example 1: After new-workload
User: `$coco-iac-agent-git-push` (after MARKETING squad was onboarded in test)
Assistant: Runs `git status --short`, sees `create_role.tfvars`, `create_warehouse.tfvars`, `create_schema.tfvars` modified. Outputs:
- Branch: `feat/test-add-marketing-workload`
- Commit: `feat(configs): onboard MARKETING squad — role, warehouse, schema in test`
- git add for those 3 files only
- Full command block ready to copy-paste

### Example 2: After new-role-user
User: `$coco-iac-agent push my changes` (after adding JSMITH in prod)
Assistant: Routes here from router. Sees `create_users.tfvars` modified in `live/prod/configs/`. Outputs:
- Branch: `feat/prod-add-jsmith-user`
- Commit: `feat(configs): add JSMITH user with ANALYST_ROLE in prod`
- git add for `live/prod/configs/create_users.tfvars` only

### Example 3: Multiple files, mixed stacks
User: `$coco-iac-agent-git-push` (roles + users changed in test)
Assistant: Sees `create_role.tfvars` and `create_users.tfvars` modified. Generates one branch covering both (same session, same env). Outputs combined commit message listing both changes. Notes: if these are unrelated changes, split into two PRs.

### Example 4: Nothing to push
User: `$coco-iac-agent-git-push`
Assistant: Runs `git status --short`, output is clean. Responds: "Nothing to commit — working tree is clean. If you just applied changes, verify the correct `live/<env>/configs/` files were modified."
