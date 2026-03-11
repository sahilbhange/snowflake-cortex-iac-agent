variable "stages" {
  description = "Map of stages to manage (key = stage name)."
  type = map(object({
    database            = optional(string)
    schema              = optional(string)
    url                 = optional(string)
    storage_integration = optional(string)
    comment             = optional(string)
  }))
  default = {}
}

variable "database" {
  type     = string
  default  = null
  nullable = true
}

variable "schema" {
  type     = string
  default  = null
  nullable = true
}

variable "name" {
  type     = string
  default  = null
  nullable = true
}

variable "url" {
  type     = string
  default  = null
  nullable = true
}

variable "storage_integration" {
  type     = string
  default  = null
  nullable = true
}

variable "comment" {
  type     = string
  default  = null
  nullable = true
}

locals {
  explicit_stages = {
    for stage_name, cfg in var.stages : trimspace(stage_name) => {
      database            = coalesce(try(cfg.database, null), var.database)
      schema              = coalesce(try(cfg.schema, null), var.schema)
      url                 = try(cfg.url, var.url)
      storage_integration = try(cfg.storage_integration, var.storage_integration)
      comment             = try(cfg.comment, var.comment)
    }
    if trimspace(stage_name) != ""
  }

  legacy_stage = (
    var.name == null || try(trimspace(var.name), "") == "" ? {} : {
      trimspace(var.name) = {
        database            = var.database
        schema              = var.schema
        url                 = var.url
        storage_integration = var.storage_integration
        comment             = var.comment
      }
    }
  )

  resolved_stages = length(var.stages) > 0 ? local.explicit_stages : local.legacy_stage
}

resource "snowflake_stage" "this" {
  for_each = local.resolved_stages

  name      = each.key
  database  = each.value.database
  schema    = each.value.schema
  url       = each.value.url
  comment   = each.value.comment

  storage_integration = each.value.storage_integration
}

output "stage_fqns" {
  value       = { for stage_name, stage in snowflake_stage.this : stage_name => "${stage.database}.${stage.schema}.${stage.name}" }
  description = "Map of stage FQNs managed by this module."
}

output "stage_fqn" {
  value = length(snowflake_stage.this) == 0 ? null : (
    var.name != null && try(trimspace(var.name), "") != "" && try(contains(keys(snowflake_stage.this), trimspace(var.name)), false)
      ? "${snowflake_stage.this[trimspace(var.name)].database}.${snowflake_stage.this[trimspace(var.name)].schema}.${snowflake_stage.this[trimspace(var.name)].name}"
      : "${values(snowflake_stage.this)[0].database}.${values(snowflake_stage.this)[0].schema}.${values(snowflake_stage.this)[0].name}"
  )
  description = "Legacy single stage FQN output for backwards compatibility."
}
