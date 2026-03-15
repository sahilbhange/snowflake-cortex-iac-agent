# Naming Conventions

Single source of truth for all Snowflake object names in this repo.
All creation skills (`new-workload`, `new-role-user`, `account-objects`) read this file
during the **NAME PROPOSAL** step — before generating any tfvars content.

---

## Universal Rules

- All Snowflake object names **UPPERCASE**
- Terraform resource labels **snake_case** (derived from object name)
- Apply env suffix in non-prod environments:
  - `_TEST` in `live/test/`
  - `_STAGE` in `live/stage/`
  - No suffix in `live/prod/`
- Access roles are **account-level shared objects** — no env suffix because they define data-layer privileges consistent across environments
- ⚠️ This assumes a **single Snowflake account** serving all environments. If using separate accounts per env, access roles would need env suffixes.
- **Exception**: User login names may use lowercase for readability (`jsmith`), but Snowflake stores them as UPPERCASE internally
- No spaces, no special characters except underscore

---

## Object Type Patterns

| Object Type | Pattern | Example (test) | Example (prod) | Env Suffix |
|-------------|---------|----------------|----------------|------------|
| Access role (read) | `<OBJECT>_READ` | `GROWTH_READ` | `GROWTH_READ` | No (shared) |
| Access role (write) | `<OBJECT>_WRITE` | `GROWTH_WRITE` | `GROWTH_WRITE` | No (shared) |
| Access role (scoped) | `<OBJECT>_<PRIVILEGE>` | `ANALYTICS_MART_READ` | `ANALYTICS_MART_READ` | No (shared) |
| Functional role | `<TEAM>_ROLE` | `GROWTH_ROLE_TEST` | `GROWTH_ROLE` | Yes |
| Warehouse | `<TEAM>_WH` | `GROWTH_WH_TEST` | `GROWTH_WH` | Yes |
| Database | `<PURPOSE>_DB` | `RAW_DB` | `RAW_DB` | No (usually shared) |
| Schema | `<PURPOSE>` (no `_SCHEMA` suffix) | `GROWTH_MART_TEST` | `GROWTH_MART` | Yes |
| User (human) | lowercase `<first><last>` | `jsmith` | `jsmith` | No |
| User (service account) | lowercase `<purpose>_svc` or `<team>_runner` | `etl_svc_test` | `etl_svc` | Optional |
| Resource monitor | `RM_<SCOPE>_<LIMIT>` | `RM_MONTHLY_LIMIT_TEST` | `RM_MONTHLY_LIMIT` | Yes |
| Network rule | `<PURPOSE>_NETWORK_RULE` | `PYPI_NETWORK_RULE_TEST` | `PYPI_NETWORK_RULE` | Yes |
| External access integration | `<PURPOSE>_ACCESS_INTEGRATION` | `PYPI_ACCESS_INTEGRATION_TEST` | `PYPI_ACCESS_INTEGRATION` | Yes |
| Stage | `<PURPOSE>_<SOURCE>` | `RAW_S3_TEST` | `RAW_S3` | Yes |
| Storage integration | `<CLOUD>_<ENV>_<PURPOSE>_INT` | `AWS_DEV_S3_INT` | `AWS_PROD_S3_INT` | No (use env in name) |

---

## Derivation Rules (Natural Language → Object Names)

When the user provides a team or purpose name (e.g. "GROWTH squad", "PyPI egress", "monthly budget monitor"):

### For `new-workload` (team onboarding)

Given team name `<TEAM>`:
1. Access role (read): `<TEAM>_READ`
2. Access role (write): `<TEAM>_WRITE` — inherits `<TEAM>_READ` via `granted_roles`
3. Functional role: `<TEAM>_ROLE[_<ENV_SUFFIX>]`
4. Warehouse: `<TEAM>_WH[_<ENV_SUFFIX>]`
5. Schema: derive from purpose/description — e.g. "growth mart" → `GROWTH_MART[_<ENV_SUFFIX>]`

**Skip access role creation if an equivalent already exists** (e.g. if team only needs `RAW_READ`, do not create `GROWTH_READ`).

### For `new-role-user` (user/role additions)

Given user name `<first> <last>`:
- tfvars key (login): lowercase `<first initial><last>` — e.g. `jsmith`
- Snowflake user object name: UPPERCASE `JSMITH`
- Default role: existing `<TEAM>_ROLE[_<ENV_SUFFIX>]`
- Default warehouse: existing `<TEAM>_WH[_<ENV_SUFFIX>]`
- Workspace schema: `WORKSPACE_DB.<LOGINNAME_UPPER>`

Given service account purpose `<purpose>`:
- Login name: `<purpose>_svc` (lowercase)
- Object name: `<PURPOSE>_SVC[_<ENV_SUFFIX>]` (uppercase)

### For `account-objects` (resource monitors, network rules, EAIs)

Given resource monitor description (e.g. "monthly 500 credit limit"):
- `RM_MONTHLY_LIMIT[_<ENV_SUFFIX>]`
- `RM_DAILY_LIMIT[_<ENV_SUFFIX>]`

Given network rule purpose (e.g. "PyPI egress", "GitHub access"):
- `<PURPOSE>_NETWORK_RULE[_<ENV_SUFFIX>]`
- e.g. `PYPI_NETWORK_RULE`, `GITHUB_NETWORK_RULE`

Given EAI purpose:
- `<PURPOSE>_ACCESS_INTEGRATION[_<ENV_SUFFIX>]`
- e.g. `PYPI_ACCESS_INTEGRATION`

---

## Conflict Detection Checklist

Before proposing any name, check the following in the target env's `live/<env>/configs/`:

| File | What to scan | Conflict condition |
|------|-------------|-------------------|
| `create_role.tfvars` | All role keys | Proposed role name already present |
| `create_warehouse.tfvars` | All warehouse keys | Proposed warehouse name already present |
| `create_schema.tfvars` | All schema keys | Proposed schema name already present |
| `create_users.tfvars` | All user keys | Proposed login name already present |
| `create_resource_monitor.tfvars` | All RM keys | Proposed RM name already present |
| `create_network_rules.tfvars` | All rule keys | Proposed rule name already present |
| `create_external_access_integrations.tfvars` | All EAI keys | Proposed EAI name already present |

If a conflict is found:
- Flag it in the NAME PROPOSAL table with `⚠ CONFLICT — already exists`
- Offer an alternative name (e.g. append a qualifier: `GROWTH_MART2`, `GROWTH_ANALYTICS_READ`)
- Do NOT silently overwrite the existing entry

---

## NAME PROPOSAL Output Format

Every creation skill must present a NAME PROPOSAL table as the first user-facing output.
Use this exact format:

```
## Name Proposal — <request summary> — <env>

| Object Type | Proposed Name | Convention Applied | Env Suffix | Conflict |
|-------------|--------------|-------------------|------------|----------|
| Access role (read) | GROWTH_READ | `<TEAM>_READ` | No (shared) | None |
| Access role (write) | GROWTH_WRITE | `<TEAM>_WRITE` | No (shared) | None |
| Functional role | GROWTH_ROLE_TEST | `<TEAM>_ROLE` + `_TEST` | Yes | None |
| Warehouse | GROWTH_WH_TEST | `<TEAM>_WH` + `_TEST` | Yes | None |
| Schema | ANALYTICS_DB.GROWTH_MART_TEST | `<PURPOSE>` in target DB | Yes | None |

Approve these names, or reply with corrections before I generate any files.
```

**Gate:** Do NOT read or edit any tfvars files until the user explicitly approves the names.
Resume on "yes", "approved", "looks good", or explicit corrections ("change GROWTH_MART to GROWTH_DATA").

---

## Common Mistakes to Flag

| Pattern | Problem | Correct |
|---------|---------|---------|
| `GROWTH_ROLE_READ` | Access role named like functional role | `GROWTH_READ` |
| `GROWTH_ACCESS_ROLE` | Redundant `_ROLE` suffix on access role | `GROWTH_READ` or `GROWTH_WRITE` |
| `GROWTHWH` | Missing underscore separator | `GROWTH_WH` |
| `growth_role` | Lowercase Snowflake object name | `GROWTH_ROLE` |
| `GROWTH_SCHEMA` | `_SCHEMA` suffix — module already handles this | `GROWTH` or `GROWTH_MART` |
| `RM_GROWTH` | Resource monitor name not descriptive enough | `RM_MONTHLY_LIMIT` |
| `PYPI_RULE` | Missing `_NETWORK_RULE` suffix for network rules | `PYPI_NETWORK_RULE` |
| `PYPI_EAI` | Missing `_ACCESS_INTEGRATION` suffix | `PYPI_ACCESS_INTEGRATION` |
| Functional role without `_ROLE` suffix | e.g. `GROWTH_TEAM` | `GROWTH_ROLE` |

---

## Disambiguation Rules

**When team name is ambiguous** (e.g. "growth analytics"): use the first meaningful noun as the `<TEAM>` prefix: `GROWTH`.

**When multiple schemas needed for one team**: suffix with purpose:
- `GROWTH_MART`, `GROWTH_STAGING`, `GROWTH_RAW` — not just `GROWTH`

**When an access role already exists** for the data the team needs (e.g. `RAW_READ` exists):
- Wire the existing access role into the functional role via `granted_roles`
- Do NOT create `GROWTH_RAW_READ` — reuse `RAW_READ`
- Only create a new access role if the team needs scoped access not covered by any existing role

**When user's full name collision** (e.g. two `jsmith`):
- Use middle initial: `jbsmith`
- Or use full first name: `johnsmith`
- Flag this in the NAME PROPOSAL table with `⚠ LOGIN COLLISION`
