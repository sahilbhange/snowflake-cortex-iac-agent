# Prompt Examples

## Bootstrap (first-time setup)
```
$coco-iac-agent bootstrap-guide for test env — starting from scratch.
Validate my prerequisites and walk me through all 10 stacks. Generate plan commands only.
```

## Add a user (day-2)
```
$coco-iac-agent add a new analyst user in test:
  name: jsmith, email: jsmith@company.com
  role: ANALYST_ROLE, warehouse: ANALYST_WH, workspace schema: yes
Show me the tfvars change and the plan command.
```

## Onboard a new team
```
$coco-iac-agent onboard MARKETING squad in test:
  role: MARKETING_ANALYST_ROLE (under SYSADMIN)
  warehouse: MARKETING_WH (XSMALL, auto_suspend 60)
  schemas: ANALYTICS_DB.MARKETING_MART
  access: read-only on ANALYTICS_DB
Run plans for affected stacks and summarize risk.
```

## RBAC change
```
$coco-iac-agent route to new-role-user.
Grant ENGINEER_ROLE access to RAW_DB.LANDING schema in test.
Validate no ACCOUNTADMIN expansion. Run plan.
```

## Drift check
```
$coco-iac-agent drift-report on test all stacks.
Return stack-wise status with exit codes and ForceNew warnings.
```

## Plan review
```
$coco-iac-agent review this plan output and tell me if it is safe to apply:
[paste terraform plan output here]
```
