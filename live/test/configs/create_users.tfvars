enable_users = true

workspace_schema_database = "WORKSPACE_DB"
workspace_schema_grant_privileges = [
  "CREATE TABLE",
  "CREATE VIEW",
  "CREATE NOTEBOOK",
  "CREATE PROCEDURE",
  "CREATE FUNCTION",
  "CREATE STREAMLIT",
  "CREATE FILE FORMAT",
]

users = {
  jsmith = {
    first_name        = "Jane"
    last_name         = "Smith"
    email             = "jsmith@company.com"
    default_role      = "ENGINEER_ROLE"
    default_warehouse = "ENGINEER_WH"
    roles             = ["ENGINEER_ROLE"]
  }

  dbt_svc = {
    first_name              = "DBT"
    last_name               = "Service"
    default_role            = "TRANSFORMER_ROLE"
    default_warehouse       = "TRANSFORMER_WH"
    roles                   = ["TRANSFORMER_ROLE"]
    create_workspace_schema = false
  }

  alee = {
    first_name        = "Amy"
    last_name         = "Lee"
    email             = "alee@company.com"
    default_role      = "ANALYST_ROLE"
    default_warehouse = "ANALYST_WH"
    roles             = ["ANALYST_ROLE"]
  }

  mchen = {
    first_name        = "Marcus"
    last_name         = "Chen"
    email             = "mchen@company.com"
    default_role      = "MARKETING_ROLE"
    default_warehouse = "MARKETING_WH"
    roles             = ["MARKETING_ROLE"]
  }

  breport = {
    first_name              = "Blake"
    last_name               = "Report"
    email                   = "breport@company.com"
    default_role            = "REPORTER_ROLE"
    default_warehouse       = "REPORTER_WH"
    roles                   = ["REPORTER_ROLE"]
    create_workspace_schema = false
  }

  ci_runner = {
    first_name              = "CI"
    last_name               = "Runner"
    default_role            = "CI_ROLE"
    default_warehouse       = "CI_WH"
    roles                   = ["CI_ROLE"]
    create_workspace_schema = false
  }

  psingh = {
    first_name                             = "Priya"
    last_name                              = "Singh"
    email                                  = "psingh@company.com"
    default_role                           = "DATA_PLATFORM_ROLE"
    default_warehouse                      = "DATA_PLATFORM_WH"
    roles                                  = ["DATA_PLATFORM_ROLE"]
    workspace_schema_additional_privileges = ["CREATE PIPE", "CREATE STREAM", "CREATE TASK"]
  }

  rjones = {
    first_name        = "Rachel"
    last_name         = "Jones"
    email             = "rjones@company.com"
    default_role      = "FINANCE_ROLE"
    default_warehouse = "FINANCE_WH"
    roles             = ["FINANCE_ROLE"]
  }

  tsmith = {
    first_name        = "Tom"
    last_name         = "Smith"
    email             = "tsmith@company.com"
    default_role      = "SALES_ROLE"
    default_warehouse = "SALES_WH"
    roles             = ["SALES_ROLE"]
  }

  SAHILBHANGE = {
    first_name              = "Sahil"
    last_name               = "Bhange"
    email                   = "s.ahilbhange@gmail.com"
    default_role            = "ACCOUNTADMIN"
    default_warehouse       = "ETL_WH"
    roles                   = []
    create_workspace_schema = false
  }

  jreeves = {
    first_name        = "Julia"
    last_name         = "Reeves"
    email             = "jreeves@company.com"
    default_role      = "GROWTH_ROLE"
    default_warehouse = "GROWTH_WH"
    roles             = ["GROWTH_ROLE"]
  }
}
