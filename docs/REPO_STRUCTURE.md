# Repository Structure and Architecture

This document explains how the repo is organised and why — useful if you're extending it, debugging
unexpected plan output, or onboarding a new contributor. For day-to-day usage see
[GETTING_STARTED.md](GETTING_STARTED.md).

---

## Two-layer design

```
┌──────────────────────────────────────────────────────┐
│  CoCo AI layer  (.cortex/)                           │
│  Skills and agents that help you edit configs,       │
│  run plans, review risks, and detect drift           │
└───────────────────┬──────────────────────────────────┘
                    │ reads / edits
┌───────────────────▼──────────────────────────────────┐
│  Terraform stack  (live/ + modules/)                 │
│  The actual infrastructure — 10 independent stacks,  │
│  one per Snowflake resource type                     │
└──────────────────────────────────────────────────────┘
```

CoCo is optional. Every stack can be planned and applied manually from the terminal.
The Terraform layer has no dependency on CoCo.

---

## Directory layout

```
snowflake-cortex-iac-agent/
│
├── live/                          ← environment roots
│   ├── test/
│   │   ├── account.auto.tfvars   ← credentials (gitignored — never commit)
│   │   ├── configs/              ← all object declarations (edit these for changes)
│   │   │   ├── create_role.tfvars
│   │   │   ├── create_database.tfvars
│   │   │   ├── create_users.tfvars
│   │   │   ├── create_warehouse.tfvars
│   │   │   ├── create_resource_monitor.tfvars
│   │   │   ├── create_storage_integration_s3.tfvars
│   │   │   ├── create_schema.tfvars
│   │   │   ├── create_network_rules.tfvars
│   │   │   ├── create_external_access_integrations.tfvars
│   │   │   └── create_stage_s3.tfvars
│   │   ├── account_governance/
│   │   │   ├── roles/            ← stack 1
│   │   │   └── users/            ← stack 3
│   │   ├── platform/
│   │   │   ├── databases/        ← stack 2
│   │   │   ├── warehouses/       ← stack 4
│   │   │   ├── resource_monitors/        ← stack 5
│   │   │   ├── storage_integrations_s3/  ← stack 6 (SnowSQL)
│   │   │   ├── network_rules/            ← stack 8
│   │   │   └── external_access_integrations/ ← stack 9 (SnowSQL)
│   │   └── workloads/
│   │       ├── schemas/          ← stack 7
│   │       └── stages/           ← stack 10
│   └── prod/                     ← same structure as test
│
├── modules/                      ← reusable Terraform modules
│   ├── roles/
│   ├── databases/
│   ├── users/
│   ├── warehouses/
│   ├── resource_monitors/
│   ├── storage_integration_s3/
│   ├── schemas/
│   ├── network_rules/
│   ├── external_access_integrations/
│   └── stages/
│
├── bootstrap/                    ← first-time provisioning scripts
│   ├── bootstrap.sh              ← macOS / Linux
│   ├── bootstrap.ps1             ← Windows PowerShell
│   └── BOOTSTRAP.md
│
├── scripts/                      ← safety-wrapped Terraform helpers (never raw terraform apply)
│   ├── stack-plan.sh             ← plan a single stack with correct -var-file flags
│   ├── stack-apply.sh            ← safe apply: pre-flight checks + ForceNew/destroy-only guards + human [y/N]
│   ├── apply-changes.sh          ← multi-stack day-2 workflow: delegates to stack-apply.sh per stack + Snow CLI validation
│   └── scan-forcenew.sh          ← scan a plan output for ForceNew replacements (exit 2 on detection)
│
├── .cortex/                      ← CoCo skills and agents
│   └── skills/
│       ├── coco-iac-agent/                    ← parent router skill (model-agnostic)
│       ├── coco-iac-agent-new-workload/       ← onboard new team (role + warehouse + schemas)
│       ├── coco-iac-agent-new-role-user/      ← add users / RBAC changes
│       ├── coco-iac-agent-plan-review/        ← risk classification + compliance check
│       ├── coco-iac-agent-bootstrap-guide/    ← non-autonomous: pre-flight + script handoff
│       └── coco-iac-agent-drift-report/       ← autonomous: runs all 10 plans, consolidated report
│
├── references/                   ← domain knowledge (read by CoCo, useful for humans)
│   ├── guardrails.md             ← safety rules, command format, skill routing enforcement
│   ├── stack-mapping.md          ← execution order, provider aliases, env naming
│   ├── hcl-patterns.md           ← copy-paste HCL blocks for every resource type
│   ├── rbac-design.md            ← two-layer RBAC model, access role table, privilege matrix
│   ├── workflow.md               ← plan-only contract, ForceNew rules
│   ├── prompt-examples.md        ← example CoCo invocations
│   └── architecture.mmd          ← provider/module dependency diagram (Mermaid)
│
└── docs/                         ← user guides
    ├── GETTING_STARTED.md        ← CoCo usage (5 workflows)
    ├── DAY2_WORKFLOW.md          ← end-to-end 8-step workflow for infrastructure changes
    ├── REPO_STRUCTURE.md         ← this file
    ├── TERRAFORM_IMPORT.md       ← importing an existing Snowflake account into Terraform
    ├── COCO_SKILL_GUIDE.md       ← how to build CoCo skills and agents
    └── FUTURE_SCOPE.md           ← planned improvements (roadmap — not current functionality)
```

---

## How the configs pattern works

Every change to Snowflake infrastructure follows the same flow:

```
Edit configs/*.tfvars
        ↓
bash scripts/stack-plan.sh <env> <layer> <stack> --run
        ↓
scan-forcenew.sh (auto-run by stack-apply.sh — hard-stops on ForceNew)
        ↓
bash scripts/stack-apply.sh <env> <layer> <stack>   ← human runs this, never CoCo
```

For multiple stacks at once:
```bash
bash scripts/apply-changes.sh <env> <layer/stack> [<layer/stack> ...]
```
Delegates to `stack-apply.sh` per stack — same safety checks, plus Snow CLI validation and a summary report.

**Why not raw `terraform apply`?** Missing `-var-file` flags cause Terraform to use empty defaults
and destroy all resources in the stack. The scripts enforce correct flag injection on every run.
The modules read them via `for_each` maps — adding a role means adding one entry to
`create_role.tfvars`, not touching any Terraform module code.

Example:
```hcl
# live/test/configs/create_role.tfvars
roles = {
  ANALYST_ROLE_TEST = {
    comment          = "Analytics squad"
    parent_role_name = "SYSADMIN"
  }
}
```

---

## Stack isolation

Each stack directory (e.g., `live/test/platform/databases`) is a standalone Terraform root:
- Its own `terraform.tfstate` (local by default, remote optional via `backend.tf`)
- Its own `provider` block with the appropriate role alias
- No Terraform-level dependencies on other stacks

**Cross-stack references use stable Snowflake object names**, not Terraform resource IDs.
For example, `create_users.tfvars` references `default_role = "ANALYST_ROLE_TEST"` by name —
not by a Terraform output from the roles stack. This means stacks can be planned independently
without the others being initialised.

This design trades automation convenience for safety: a broken roles stack cannot cascade
failures into the users stack.

---

## Provider alias ownership

Three Snowflake roles are used as Terraform providers, each scoped to what that role can manage:

| Alias | Snowflake role | Manages |
|---|---|---|
| `snowflake.secadmin` | SECURITYADMIN | Roles, users, network rules |
| `snowflake.sysadmin` | SYSADMIN | Databases, warehouses, schemas, stages |
| `snowflake.accountadmin` | ACCOUNTADMIN | Resource monitors, storage integrations, external access integrations |

Using the wrong alias will cause silent drift or permission errors. CoCo enforces this in
`plan-review` and flags violations.

---

## Naming conventions

| Object type | Pattern | Example |
|---|---|---|
| Roles | `<TEAM>_ROLE` | `ANALYST_ROLE`, `ANALYST_ROLE_TEST` |
| Warehouses | `<TEAM>_WH` | `ANALYST_WH`, `ANALYST_WH_TEST` |
| Databases | `<PURPOSE>_DB` | `ANALYTICS_DB`, `RAW_DB` |
| Schemas | `<PURPOSE>` (no `_SCHEMA` suffix) | `MART`, `FINANCE` |
| Users | `FIRST_LAST` or `TEAM_SVC` | `JSMITH`, `ETL_SVC` |

Environment suffixes (recommended for real deployments):
- `_TEST` in `live/test/`
- `_STAGE` in `live/stage/` (if used)
- No suffix in `live/prod/`

> **Demo configs:** The example configs in this repo use unsuffixed names (`ANALYST_ROLE`, `ANALYTICS_WH`) for simplicity. In a real multi-environment deployment, apply the suffix so test and prod objects are distinct in the Snowflake UI and audit logs.

All Snowflake object names UPPERCASE. Terraform resource labels snake_case.

---

## Role hierarchy

```
ACCOUNTADMIN            (never referenced in Terraform — configure manually)
  └── SECURITYADMIN     (used by secadmin alias — manages all roles and users)
        └── SYSADMIN    (used by sysadmin alias — manages all data objects)
              └── <TEAM>_ROLE   (functional roles — one per team or workload)
```

All functional roles are granted to SYSADMIN as their parent. ACCOUNTADMIN is never
granted to functional or service roles via Terraform.

---

## SnowSQL escape hatches

Two operations are unsupported by the Terraform provider and handled via `local-exec`:

| Operation | Stack path | Why |
|---|---|---|
| Storage integrations | `platform/storage_integrations_s3/` | Requires ACCOUNTADMIN `local-exec` |
| External access integrations | `platform/external_access_integrations/` | Same |

Additionally, **database renames** are not supported in-place — they force replacement.
Use the SnowSQL escape hatch in `platform/database_rename/` and follow its README.

Stacks 6 and 9 require SnowSQL on PATH. Verify before applying:
```bash
snow sql -c <your_connection> -q "SELECT CURRENT_USER(), CURRENT_ROLE()"
```

---

## v2.x provider — critical resource names

This repo uses `snowflakedb/snowflake ~> 2.14`. The deprecated 0.x resource names cause
silent drift or errors in v2.x:

| Use this | Not this |
|---|---|
| `snowflake_account_role` | `snowflake_role` |
| `snowflake_grant_privileges_to_account_role` | `snowflake_grant_privileges_to_role` |
| `snowflake_grant_account_role` | `snowflake_grant_role` |

See [`references/hcl-patterns.md`](../references/hcl-patterns.md) for correct copy-paste blocks.

---

## CoCo layer

The `.cortex/skills/` directory contains all CoCo skills and agents. They are loaded
automatically when CoCo starts in this repo. For install instructions see
[`docs/COCO_SKILL_GUIDE.md`](COCO_SKILL_GUIDE.md).

| Skill / Agent | Type | Purpose |
|---|---|---|
| `$coco-iac-agent` | Skill (router) | Entry point — routes to the right skill or agent |
| `$coco-iac-agent-new-workload` | Skill | Role + warehouse + schemas for a new team |
| `$coco-iac-agent-new-role-user` | Skill | Add users, create roles, update RBAC |
| `$coco-iac-agent-plan-review` | Skill | Risk classification + standards compliance check |
| `$coco-iac-agent-drift-report` | Agent (autonomous) | Runs all 10 plans, returns consolidated report |
| `$coco-iac-agent-bootstrap-guide` | Agent (non-autonomous) | Pre-flight checks + bootstrap script handoff |

See [`references/architecture.mmd`](../references/architecture.mmd) for the provider/module dependency diagram (render with any Mermaid-compatible viewer or paste into [mermaid.live](https://mermaid.live)).
