# Workflow Reference

## Execution Contract
1. Confirm scope: environment, stack path, expected object changes
2. Use plan-first commands only — never apply without explicit human confirmation in session
3. Summarize exactly what will change and why
4. Call out ForceNew replacements and RBAC privilege expansion
5. Output `bash scripts/stack-apply.sh <env> <layer> <resource>` for the user to run — CoCo never executes apply
6. **NEVER output raw `terraform apply` commands** — missing `-var-file` flags destroy all resources

## Guardrails
- Never run `terraform destroy` by default
- Never print or read private key file contents
- Prefer minimal diffs and stack-local changes (one stack at a time)
- Route unsupported provider behavior to SnowSQL escape hatches
- ForceNew scan: if a plan contains `# forces replacement`, treat as HIGH RISK and stop
  ```bash
  terraform plan -no-color ... | tee plan.out
  bash scripts/scan-forcenew.sh plan.out   # exit 2 on ForceNew
  ```
  Bootstrap enforces this automatically (hard-stop).

## Drift Check Exit Codes
```bash
terraform plan -detailed-exitcode ...
# exit 0 = no changes (no drift)
# exit 1 = error
# exit 2 = changes detected (drift or pending resources)
```

## ForceNew Risk Classification
- Database / warehouse / role with `# forces replacement` → HIGH RISK, stop
- Schema with `# forces replacement` → MEDIUM RISK, explain scope of impact
- `snowflake_user.login_name` change → ForceNew — HIGH RISK on existing users
- `snowflake_schema.with_managed_access` change → ForceNew — flag before applying

## Post-Apply Checklist

### State Check
Verify resources are tracked in Terraform state:
```bash
cd live/<env>/<layer>/<stack> && terraform state list
terraform state show '<resource_address>'
```

### Validate in Snowflake
```bash
snow sql -c <connection> -q "SHOW ROLES LIKE '<NAME>%';"
snow sql -c <connection> -q "SHOW USERS LIKE '<NAME>';"
snow sql -c <connection> -q "SHOW GRANTS TO USER <USERNAME>;"
snow sql -c <connection> -q "SHOW GRANTS OF ROLE <ROLE>;"
snow sql -c <connection> -q "SHOW WAREHOUSES LIKE '<NAME>%';"
snow sql -c <connection> -q "SHOW SCHEMAS IN DATABASE <DB>;"
```
Run only the queries relevant to what was applied.


