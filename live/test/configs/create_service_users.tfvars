enable_service_users = true

service_users = {
  #  dbt transformation service 
  DBT_SVC = {
    display_name      = "dbt Service Account"
    default_role      = "TRANSFORMER_ROLE"
    default_warehouse = "TRANSFORMER_WH"
    roles             = ["TRANSFORMER_ROLE"]
    comment           = "Service account for dbt transformations — key-pair auth only"
  }

  #  CI/CD runner 
  CI_RUNNER = {
    display_name      = "CI Runner Service Account"
    default_role      = "CI_ROLE"
    default_warehouse = "CI_WH"
    roles             = ["CI_ROLE"]
    comment           = "Service account for CI/CD pipelines — key-pair auth only"
  }

  #  Reporting / BI connector 
  BREPORT = {
    display_name      = "BI Report Service Account"
    default_role      = "REPORTER_ROLE"
    default_warehouse = "REPORTER_WH"
    roles             = ["REPORTER_ROLE"]
    comment           = "Service account for BI reporting tools — key-pair auth only"
  }
}
