variable "network_rules" {
  description = "Map of network rules to manage (key = network rule name)."
  type = map(object({
    database    = string
    schema      = string
    type        = string
    mode        = string
    value_list  = list(string)
    comment     = optional(string)
  }))
  default = {}
}

variable "name" {
  type     = string
  default  = null
  nullable = true
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

variable "type" {
  type     = string
  default  = null
  nullable = true
}

variable "mode" {
  type     = string
  default  = null
  nullable = true
}

variable "value_list" {
  type     = list(string)
  default  = []
}

variable "comment" {
  type     = string
  default  = null
  nullable = true
}

locals {
  explicit_rules = {
    for rule_name, cfg in var.network_rules : trimspace(rule_name) => {
      database   = cfg.database
      schema     = cfg.schema
      type       = upper(cfg.type)
      mode       = upper(cfg.mode)
      value_list = distinct([for v in cfg.value_list : trimspace(v)])
      comment    = try(cfg.comment, var.comment)
    }
    if trimspace(rule_name) != ""
  }

  legacy_rule = (
    var.name == null || try(trimspace(var.name), "") == "" ? {} : {
      trimspace(var.name) = {
        database   = var.database
        schema     = var.schema
        type       = upper(coalesce(var.type, "HOST_PORT"))
        mode       = upper(coalesce(var.mode, "EGRESS"))
        value_list = length(var.value_list) == 0 ? [] : distinct([for v in var.value_list : trimspace(v)])
        comment    = var.comment
      }
    }
  )

  resolved_rules = length(var.network_rules) > 0 ? local.explicit_rules : local.legacy_rule
}

resource "snowflake_network_rule" "this" {
  for_each = local.resolved_rules

  name       = each.key
  database   = each.value.database
  schema     = each.value.schema
  type       = each.value.type
  mode       = each.value.mode
  value_list = each.value.value_list
  comment    = each.value.comment
}

output "network_rule_names" {
  value       = { for rule_name, rule in snowflake_network_rule.this : rule_name => rule.name }
  description = "Map of network rule names managed by this module."
}

output "network_rule_full_names" {
  value       = { for rule_name, rule in snowflake_network_rule.this : rule_name => "${rule.database}.${rule.schema}.${rule.name}" }
  description = "Map of fully qualified network rule names."
}

output "network_rule_name" {
  value = length(snowflake_network_rule.this) == 0 ? null : (
    var.name != null && try(trimspace(var.name), "") != "" && try(contains(keys(snowflake_network_rule.this), trimspace(var.name)), false)
      ? snowflake_network_rule.this[trimspace(var.name)].name
      : values(snowflake_network_rule.this)[0].name
  )
  description = "Legacy single network rule output."
}
