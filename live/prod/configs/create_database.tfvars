enable_database = true

databases = {
  RAW_DB = {
    comment                     = "Landing zone — raw source data, external stage loads"
    data_retention_time_in_days = 7
  }
  ANALYTICS_DB = {
    comment                     = "Transformed and modeled data — dbt output, presentation layer"
    data_retention_time_in_days = 7
  }
  SHARED_DB = {
    comment                     = "Cross-team shared objects — lookup tables, audit, utils"
    data_retention_time_in_days = 7
  }
  ADMIN_DB = {
    comment                     = "Platform infrastructure — network rules, policies, tags, governance objects"
    data_retention_time_in_days = 1
  }
  WORKSPACE_DB = {
    comment                     = "Personal dev workspaces — one schema per engineer (WORKSPACE_DB.<username>)"
    data_retention_time_in_days = 1
  }
  PIPELINES_DB = {
    comment                     = "Data Platform infrastructure — orchestration, quality checks, metadata"
    data_retention_time_in_days = 14
  }
}
