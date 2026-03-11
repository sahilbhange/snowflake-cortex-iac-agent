locals {
  platform_database_names = {}
  legacy_database_name    = null
  default_database        = var.schema_database

  explicit_schemas = {
    for name, cfg in var.schemas : trimspace(name) => {
      database = coalesce(try(cfg.database, null), local.default_database)
      comment  = try(cfg.comment, null)
    }
    if trimspace(name) != ""
  }

  legacy_schema = var.schema_name == null ? {} : {
    trimspace(var.schema_name) = {
      database = coalesce(var.schema_database, local.default_database)
      comment  = var.schema_comment
    }
  }

  resolved_schemas = length(var.schemas) > 0 ? local.explicit_schemas : local.legacy_schema
}

module "schema" {
  for_each  = var.enable_schema ? local.resolved_schemas : {}
  source    = "../../../../modules/schemas"
  providers = { snowflake = snowflake.sysadmin }

  database = each.value.database
  name     = each.key
  comment  = each.value.comment
}
