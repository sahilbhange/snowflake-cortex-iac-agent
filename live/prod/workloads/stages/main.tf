locals {
  legacy_stage = (
    var.stage_name == null || try(trimspace(var.stage_name), "") == "" ? {} : {
      trimspace(var.stage_name) = {
        database            = coalesce(var.stage_database, null)
        schema              = var.stage_schema
        url                 = var.stage_url
        storage_integration = var.stage_storage_integration
        comment             = var.stage_comment
      }
    }
  )

  resolved_stages = length(var.stages) > 0 ? var.stages : local.legacy_stage
}

module "stage" {
  count     = var.enable_stage ? 1 : 0
  source    = "../../../../modules/stages"
  providers = { snowflake = snowflake.sysadmin }

  stages              = { for name, cfg in local.resolved_stages : trimspace(name) => cfg }
  database            = var.stage_database
  schema              = var.stage_schema
  name                = var.stage_name
  url                 = var.stage_url
  storage_integration = var.stage_storage_integration
  comment             = var.stage_comment
}
