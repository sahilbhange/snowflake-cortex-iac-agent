# scripts/

Four safety-wrapper scripts that sit between you and raw Terraform commands.
Read this before touching the scripts or wondering why they exist.

---

## The core problem they solve

Raw `terraform apply` is dangerous in a configs-driven repo. Every stack reads
object declarations from a `configs/*.tfvars` file via `for_each`. If that file
is missing, empty, or not passed with `-var-file`, Terraform sees an **empty
map** and plans to **destroy every resource in the stack** — with no warning
and no way to distinguish it from a legitimate destroy.

Real ways this silently happens:
- Forgot `-var-file` flag entirely
- Broken line continuation (`\`) in a multi-line command → second `-var-file` dropped
- Wrong working directory → relative path resolves to nothing
- Typo in config filename → file not found → empty map

The scripts make all of these impossible by construction.

---

## Why not just use raw terraform commands?

```bash
# This looks fine. It is not.
cd live/test/platform/warehouses
terraform apply   # no -var-file → empty for_each → destroys all 7 warehouses
```

Terraform does not error on a missing `-var-file` for an optional variable — it
uses the default (empty map). The plan will show `7 to destroy, 0 to add` and
Terraform will happily proceed if you type `yes`.

This has happened in production Snowflake environments. The scripts exist
because humans (and AI agents) make this mistake.

---

## Script overview

```
stack-plan.sh       Plan a single stack safely
stack-apply.sh      Apply a single stack with full pre-flight + human gate
apply-changes.sh    Multi-stack day-2 workflow (delegates to stack-apply.sh)
scan-forcenew.sh    Scan a saved plan output for ForceNew replacements
```

---

## stack-plan.sh

**What it does:**
Wraps `terraform plan` with correct `-var-file` flags, pre-flight checks, and
optional `terraform init`.

**Usage:**
```bash
bash scripts/stack-plan.sh <env> <layer> <resource> [--run] [--drift]
```

**Without `--run`** — prints the plan command only (safe, no side effects):
```bash
bash scripts/stack-plan.sh test platform warehouses
# Output: Stack: live/test/platform/warehouses
#         Command: terraform plan -no-color -var-file=... -var-file=...
```

**With `--run`** — runs pre-flight checks then executes the plan:
```bash
bash scripts/stack-plan.sh test platform warehouses --run
```

**With `--drift`** — adds `-detailed-exitcode` for drift detection (exit 2 = drift detected):
```bash
bash scripts/stack-plan.sh test platform warehouses --run --drift
```

**Pre-flight checks (when `--run`):**
1. Stack directory exists
2. `account.auto.tfvars` exists
3. Config tfvars file exists (missing → empty for_each → destroy-all plan)
4. Config file is not empty

**Why CoCo runs this but not stack-apply.sh:**
CoCo is allowed to run `stack-plan.sh --run` and show you the output — that's
read-only. Apply is irreversible, so only humans run `stack-apply.sh`.

---

## stack-apply.sh

**What it does:**
The main safety wrapper for applying a single stack. Enforces a mandatory plan,
multiple risk checks, and a human confirmation before any `terraform apply`.

**Usage:**
```bash
bash scripts/stack-apply.sh <env> <layer> <resource>
```

**TTY guard — the hard AI block:**
The very first thing the script does is check for an interactive terminal:
```bash
if [[ ! -t 0 ]]; then
  echo "ERROR: stack-apply.sh requires an interactive terminal (TTY)."
  exit 1
fi
```
If stdin is not a TTY — meaning it's being called from a pipe, background
process, AI agent, or any non-interactive context — it exits immediately.
This is a technical enforcement of the "humans run apply" rule. It cannot be
bypassed by prompt engineering or model instructions.

**Full safety pipeline before any apply:**

| Check | What it prevents |
|---|---|
| Config file exists | Missing `-var-file` → empty map → destroys all resources |
| Config file not empty | Empty tfvars → same outcome as missing |
| Mandatory plan | No apply without reviewing what will change |
| ForceNew detection | Database/warehouse/role replace = data loss |
| Destroy-only detection | 0 adds + N destroys = config not loaded correctly |
| Empty `for_each` detection | "key not in for_each map" = var-file was dropped |
| Destroy > add warning | More resources destroyed than created = suspicious |
| Human `[y/N]` confirmation | Final human gate before `terraform apply -auto-approve` |

**Why `--auto-approve` still exists:**
Real CI pipelines (GitHub Actions, GitLab CI) attach a pseudo-TTY via
`script -q` or `docker run -t`. The TTY guard still passes in those cases
because a TTY is genuinely attached. `--auto-approve` then skips only the
`[y/N]` prompt — all other safety checks still run.

**What happens on ForceNew or destroy-only:**
The script exits with code `2` (BLOCKED) and prints the exact command you
would need to run manually if you are certain it is intentional. It does not
proceed.

---

## apply-changes.sh

**What it does:**
Multi-stack orchestrator for day-2 workflows. Calls `stack-apply.sh` for each
stack in order, then runs Snow CLI validation queries and prints a change summary.

**Usage:**
```bash
bash scripts/apply-changes.sh <env> <layer/stack> [<layer/stack> ...]
```

**Example — onboarding a new team touches 4 stacks:**
```bash
bash scripts/apply-changes.sh test \
  account_governance/roles \
  platform/warehouses \
  workloads/schemas \
  account_governance/users
```

**Why it delegates to stack-apply.sh instead of reimplementing apply:**
An earlier version of this script had its own copy of the plan + apply logic.
That meant two places to maintain safety checks, and the multi-stack path had
weaker guards than the single-stack path. Delegating to `stack-apply.sh` means
every stack in a multi-stack run gets the full safety pipeline — ForceNew
detection, destroy-only detection, human confirmation, TTY guard — with no
duplication.

**What it adds on top of stack-apply.sh:**
- Step numbering across stacks
- Snow CLI validation queries after apply (SHOW ROLES, SHOW WAREHOUSES, etc.)
- Final summary: applied / skipped / failed per stack

**Exit code handling from stack-apply.sh:**
- `0` → applied or no changes → `APPLIED_STACKS`
- `2` → BLOCKED (ForceNew or destroy-only) → `FAILED_STACKS`, continues to next stack
- `1` → pre-flight failed → `FAILED_STACKS`, continues to next stack

A blocked stack does not abort the entire run — subsequent stacks still execute.

---

## scan-forcenew.sh

**What it does:**
Scans a saved Terraform plan output file for `# forces replacement` lines and
exits with code `2` if any are found.

**Usage:**
```bash
plan_out=$(mktemp)
bash scripts/stack-plan.sh test platform warehouses --run 2>&1 | tee "$plan_out"
bash scripts/scan-forcenew.sh "$plan_out"
```

**Exit codes:**
- `0` — no ForceNew detected, safe to proceed
- `2` — ForceNew detected, stop and investigate

**Why ForceNew is HIGH RISK for Snowflake objects:**
Terraform ForceNew means the resource must be destroyed and recreated. For most
cloud resources that is inconvenient. For Snowflake:
- **Database ForceNew** → all tables, schemas, and data inside are destroyed
- **Warehouse ForceNew** → warehouse is dropped (no data loss, but downtime)
- **Role ForceNew** → role is dropped, all grants to that role are lost

`stack-apply.sh` runs this scan automatically and blocks on exit code `2`.
The standalone script is useful when you want to scan a plan that was saved
separately (e.g., from a CI pipeline or bootstrap run).

---

## Relationship between the four scripts

```
stack-plan.sh          ← CoCo runs this, shows you the output
      ↓ (output saved to file)
scan-forcenew.sh       ← called automatically by stack-apply.sh
      ↓
stack-apply.sh         ← YOU run this after reviewing the plan
      ↑
apply-changes.sh       ← calls stack-apply.sh once per stack in the list
```

CoCo's role ends after `stack-plan.sh`. Everything to the right of that arrow
is a human action, enforced technically by the TTY guard.

---

## The "why not just trust the AI?" answer

Prompt instructions and SKILL.md guardrails are model-level enforcement — they
work until they don't. A sufficiently confident model, a jailbreak, or a future
model update could cause CoCo to attempt to run `stack-apply.sh`. The TTY guard
means that even if CoCo tries, the script exits before doing anything. The
technical enforcement does not rely on model compliance.

This is the same principle as `prevent_destroy = true` in Terraform lifecycle
blocks — you do not rely on humans remembering not to destroy critical resources,
you make the tool refuse.
