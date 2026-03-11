enable_role = true

roles = {

  # ── Access Roles ────────────────────────────────────────────────────────────
  # Never assigned to users directly. Granted INTO functional roles.

  RAW_READ = {
    comment      = "Read access on RAW_DB — all schemas, all tables"
    parent_roles = ["SYSADMIN"]
  }

  RAW_WRITE = {
    comment       = "Read/write access on RAW_DB — includes RAW_READ"
    parent_roles  = ["SYSADMIN"]
    granted_roles = ["RAW_READ"]
  }

  ANALYTICS_READ = {
    comment      = "Read access on ANALYTICS_DB — all schemas, all tables"
    parent_roles = ["SYSADMIN"]
  }

  ANALYTICS_WRITE = {
    comment       = "Read/write access on ANALYTICS_DB — includes ANALYTICS_READ"
    parent_roles  = ["SYSADMIN"]
    granted_roles = ["ANALYTICS_READ"]
  }

  ANALYTICS_MART_READ = {
    comment      = "Read-only on ANALYTICS_DB.MART and ANALYTICS_DB.REPORTING — BI/dashboard consumers"
    parent_roles = ["SYSADMIN"]
  }

  MARKETING_WRITE = {
    comment      = "Read/write on ANALYTICS_DB.CAMPAIGNS and ANALYTICS_DB.ATTRIBUTION only"
    parent_roles = ["SYSADMIN"]
  }

  PIPELINES_WRITE = {
    comment      = "Read/write access on PIPELINES_DB — all schemas"
    parent_roles = ["SYSADMIN"]
  }

  SHARED_READ = {
    comment      = "Read access on SHARED_DB — all schemas, all tables"
    parent_roles = ["SYSADMIN"]
  }

  SHARED_WRITE = {
    comment       = "Read/write access on SHARED_DB — includes SHARED_READ"
    parent_roles  = ["SYSADMIN"]
    granted_roles = ["SHARED_READ"]
  }

  FINANCE_READ = {
    comment       = "Read-only on ANALYTICS_DB.MART + SHARED_DB — Finance team consumers"
    parent_roles  = ["SYSADMIN"]
    granted_roles = ["ANALYTICS_MART_READ", "SHARED_READ"]
  }

  # ── Functional Roles ─────────────────────────────────────────────────────────
  # Assigned to humans and service accounts. Inherit privileges via access roles.

  ENGINEER_ROLE = {
    comment       = "Data engineering squad — full r/w on RAW_DB, read ANALYTICS_DB"
    parent_roles  = ["SYSADMIN"]
    granted_roles = ["RAW_WRITE", "ANALYTICS_READ", "SHARED_READ"]
  }

  TRANSFORMER_ROLE = {
    comment       = "dbt/ELT squad — reads RAW_DB, writes ANALYTICS_DB"
    parent_roles  = ["SYSADMIN"]
    granted_roles = ["RAW_READ", "ANALYTICS_WRITE", "SHARED_READ"]
  }

  ANALYST_ROLE = {
    comment       = "Analytics squad — reads RAW_DB, full r/w on ANALYTICS_DB"
    parent_roles  = ["SYSADMIN"]
    granted_roles = ["RAW_READ", "ANALYTICS_WRITE", "SHARED_READ"]
  }

  MARKETING_ROLE = {
    comment       = "Marketing squad — reads ANALYTICS_DB, owns CAMPAIGNS + ATTRIBUTION schemas"
    parent_roles  = ["SYSADMIN"]
    granted_roles = ["ANALYTICS_READ", "MARKETING_WRITE", "SHARED_READ"]
  }

  REPORTER_ROLE = {
    comment       = "BI/dashboard consumers — read-only on MART and REPORTING schemas"
    parent_roles  = ["SYSADMIN"]
    granted_roles = ["ANALYTICS_MART_READ"]
  }

  DATA_PLATFORM_ROLE = {
    comment       = "Data platform squad — full r/w across all operational databases"
    parent_roles  = ["SYSADMIN"]
    granted_roles = ["RAW_WRITE", "ANALYTICS_WRITE", "PIPELINES_WRITE", "SHARED_WRITE"]
  }

  CI_ROLE = {
    comment       = "CI/CD service account — pipeline automation, writes RAW_DB and ANALYTICS_DB"
    parent_roles  = ["SYSADMIN"]
    granted_roles = ["RAW_WRITE", "ANALYTICS_WRITE"]
  }

  FINANCE_ROLE = {
    comment       = "Finance squad — read analytics mart + shared data, own BUDGETS + FORECASTS schemas"
    parent_roles  = ["SYSADMIN"]
    granted_roles = ["FINANCE_READ"]
  }
}
