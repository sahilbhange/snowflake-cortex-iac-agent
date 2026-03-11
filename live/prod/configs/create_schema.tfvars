enable_schema = true

schemas = {
  # RAW_DB — source-aligned schemas, one per ingestion system
  SALESFORCE = {
    database = "RAW_DB"
    comment  = "Salesforce CRM raw data"
  }
  STRIPE = {
    database = "RAW_DB"
    comment  = "Stripe payments raw data"
  }
  EVENTS = {
    database = "RAW_DB"
    comment  = "Product event stream raw data"
  }
  LANDING = {
    database = "RAW_DB"
    comment  = "Generic landing zone for ad-hoc loads"
  }

  # ANALYTICS_DB — transformation layers (dbt-aligned)
  STAGING = {
    database = "ANALYTICS_DB"
    comment  = "dbt staging models — one-to-one with source tables"
  }
  MART = {
    database = "ANALYTICS_DB"
    comment  = "Business-facing dimensional models — BI tool target"
  }
  REPORTING = {
    database = "ANALYTICS_DB"
    comment  = "Aggregated reporting tables — dashboards and exports"
  }

  # SHARED_DB — cross-team shared objects
  UTILS = {
    database = "SHARED_DB"
    comment  = "Shared UDFs, macros, helper procedures"
  }
  AUDIT = {
    database = "SHARED_DB"
    comment  = "Access logs, query history, governance metadata"
  }

  # ADMIN_DB — platform governance objects (PUBLIC schema used by network rules stack at step 7)
  GOVERNANCE = {
    database = "ADMIN_DB"
    comment  = "Masking policies, row access policies, classification tags"
  }

  # ANALYTICS_DB — Marketing schemas
  CAMPAIGNS = {
    database = "ANALYTICS_DB"
    comment  = "Marketing campaign data and metadata"
  }
  ATTRIBUTION = {
    database = "ANALYTICS_DB"
    comment  = "Marketing attribution models and touchpoint data"
  }

  # ANALYTICS_DB — Finance schemas
  BUDGETS = {
    database = "ANALYTICS_DB"
    comment  = "Finance budget planning and actuals"
  }
  FORECASTS = {
    database = "ANALYTICS_DB"
    comment  = "Finance forecasting models and projections"
  }

  # PIPELINES_DB — Data Platform infrastructure
  ORCHESTRATION = {
    database = "PIPELINES_DB"
    comment  = "Pipeline orchestration metadata — DAG definitions, run history, scheduling"
  }
  QUALITY_CHECKS = {
    database = "PIPELINES_DB"
    comment  = "Data quality rules, test results, anomaly detection"
  }
  METADATA = {
    database = "PIPELINES_DB"
    comment  = "Catalog metadata — lineage, freshness, ownership, SLAs"
  }
}
