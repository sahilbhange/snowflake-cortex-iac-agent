# RBAC Design — Snowflake Standard Practices

## Role Taxonomy

Snowflake recommends a two-layer role model:

- **Access Roles** — own privileges on specific objects. Never assigned to humans.
- **Functional Roles** — assigned to users. Inherit privileges by having access roles granted into them.

```
SECURITYADMIN
  └── SYSADMIN
        ├── <access roles>       ← own object privileges
        └── <functional roles>   ← inherit access roles, assigned to users
```

---

## Naming Conventions

| Type | Pattern | Example |
|---|---|---|
| Access role | `<OBJECT>_<PRIVILEGE>` | `RAW_READ`, `ANALYTICS_WRITE` |
| Functional role | `<TEAM>_ROLE` | `ENGINEER_ROLE`, `MARKETING_ROLE` |
| Warehouse | `<TEAM>_WH` | `ENGINEER_WH` |
| Database | `<PURPOSE>_DB` | `RAW_DB`, `ANALYTICS_DB` |

> No `_AR` suffix — role type is documented here, not encoded in the name.

---

## Databases

| Database | Purpose |
|---|---|
| `RAW_DB` | Source ingestion — Salesforce, Stripe, Events, Landing |
| `ANALYTICS_DB` | dbt transformation layers — STAGING, MART, REPORTING, CAMPAIGNS, ATTRIBUTION |
| `PIPELINES_DB` | Data platform infra — ORCHESTRATION, QUALITY_CHECKS, METADATA |
| `SHARED_DB` | Cross-team shared objects — UTILS, AUDIT |
| `ADMIN_DB` | Platform governance — masking policies, tags, network rules |
| `WORKSPACE_DB` | Personal dev schemas — one schema per engineer (`WORKSPACE_DB.<username>`) |

---

## Access Roles

| Role | Privileges |
|---|---|
| `RAW_READ` | USAGE on RAW_DB + all schemas + SELECT on all/future tables |
| `RAW_WRITE` | Inherits RAW_READ + INSERT/UPDATE/DELETE + CREATE TABLE/STAGE on RAW_DB |
| `ANALYTICS_READ` | USAGE on ANALYTICS_DB + all schemas + SELECT on all/future tables |
| `ANALYTICS_WRITE` | Inherits ANALYTICS_READ + CREATE TABLE/VIEW/PROCEDURE in ANALYTICS_DB |
| `ANALYTICS_MART_READ` | USAGE on ANALYTICS_DB + SELECT on MART + REPORTING schemas only |
| `MARKETING_WRITE` | USAGE on ANALYTICS_DB + RW on CAMPAIGNS + ATTRIBUTION schemas only |
| `PIPELINES_WRITE` | USAGE on PIPELINES_DB + full RW on all schemas |
| `SHARED_READ` | USAGE on SHARED_DB + SELECT on all/future tables |
| `SHARED_WRITE` | Inherits SHARED_READ + CREATE TABLE/PROCEDURE on SHARED_DB |
| `FINANCE_READ` | Inherits ANALYTICS_MART_READ + SHARED_READ — Finance team read access |

> **Important:** `ANALYTICS_WRITE` inherits `ANALYTICS_READ`, `RAW_WRITE` inherits `RAW_READ`, `SHARED_WRITE` inherits `SHARED_READ`, `FINANCE_READ` inherits `ANALYTICS_MART_READ` + `SHARED_READ`. This is done via `granted_roles` in `create_role.tfvars`.

---

## Functional Roles

| Role | Inherits | Warehouse | Who |
|---|---|---|---|
| `ENGINEER_ROLE` | RAW_WRITE, ANALYTICS_READ, SHARED_READ | ENGINEER_WH | Data engineers |
| `TRANSFORMER_ROLE` | RAW_READ, ANALYTICS_WRITE, SHARED_READ | TRANSFORMER_WH | dbt / ELT service accounts |
| `ANALYST_ROLE` | RAW_READ, ANALYTICS_WRITE, SHARED_READ | ANALYST_WH | Analytics team |
| `MARKETING_ROLE` | ANALYTICS_READ, MARKETING_WRITE, SHARED_READ | MARKETING_WH | Marketing team |
| `REPORTER_ROLE` | ANALYTICS_MART_READ | REPORTER_WH | BI consumers, dashboard viewers |
| `DATA_PLATFORM_ROLE` | RAW_WRITE, ANALYTICS_WRITE, PIPELINES_WRITE, SHARED_WRITE | DATA_PLATFORM_WH | Platform engineers |
| `CI_ROLE` | RAW_WRITE, ANALYTICS_WRITE | CI_WH | CI/CD service accounts |
| `FINANCE_ROLE` | FINANCE_READ | FINANCE_WH | Finance squad |

---

## Privilege Matrix

| Role | RAW_DB | ANALYTICS_DB | ANALYTICS_DB (MART/REPORTING only) | ANALYTICS_DB (CAMPAIGNS/ATTRIBUTION) | PIPELINES_DB | SHARED_DB |
|---|---|---|---|---|---|---|
| ENGINEER_ROLE | R/W | R | — | — | — | R |
| TRANSFORMER_ROLE | R | R/W | — | — | — | R |
| ANALYST_ROLE | R | R/W | — | — | — | R |
| MARKETING_ROLE | — | R | — | R/W | — | R |
| REPORTER_ROLE | — | — | R | — | — | — |
| DATA_PLATFORM_ROLE | R/W | R/W | — | — | R/W | R/W |
| CI_ROLE | R/W | R/W | — | — | — | — |
| FINANCE_ROLE | — | — | R | — | — | R |

---

## Workspace Schemas

- Created in `WORKSPACE_DB.<username>` (uppercased)
- Only the user's own functional role(s) get privileges on their schema
- Service accounts (`dbt_svc`, `ci_runner`) have `create_workspace_schema = false`
- BI consumers (`breport`) have `create_workspace_schema = false`
- Standard privileges: CREATE TABLE, VIEW, NOTEBOOK, PROCEDURE, FUNCTION, STREAMLIT, FILE FORMAT
- Extended privileges (platform engineers): + CREATE PIPE, STREAM, TASK

---

## Key Design Decisions

1. **One grant block per role per object type** — avoids perpetual plan drift (Snowflake v2.x provider requirement)
2. **Access roles under SYSADMIN** — object privileges flow through SYSADMIN hierarchy, not SECURITYADMIN
3. **Functional roles under SYSADMIN** — inherits compute and object ownership chain correctly
4. **SECURITYADMIN manages all role grants** — `provider = snowflake.secadmin` on all `snowflake_grant_account_role` resources
5. **No ACCOUNTADMIN grants via Terraform** — ever
6. **Future grants** on tables/schemas ensure new objects are automatically covered without re-running Terraform
7. **Workspace schema grants scoped to user's own roles** — no blanket cross-team access

---

## Terraform Implementation Notes

- Access role inheritance uses `granted_roles` in `create_role.tfvars` — maps to `snowflake_grant_account_role.granted_roles` in `modules/roles/main.tf`
- `parent_roles` = "this role is granted TO parent" (role → SYSADMIN)
- `granted_roles` = "these roles are granted INTO this role" (access role → functional role)
- Object-level privileges (DB USAGE, schema SELECT, future grants) are **not yet in Terraform** — next step is a `workloads/grants` stack per database
