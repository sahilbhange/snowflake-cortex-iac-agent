variable "external_access_integrations" {
  description = "Map of external access integrations to manage (key = integration name)."
  type = map(object({
    enabled                  = optional(bool, true)
    allowed_network_rules    = optional(list(string), [])
    blocked_network_rules    = optional(list(string), [])
    allowed_api_integrations = optional(list(string), [])
    blocked_api_integrations = optional(list(string), [])
    comment                  = optional(string)
  }))
  default = {}
}

variable "name" {
  type     = string
  default  = null
  nullable = true
}

variable "enabled" {
  type    = bool
  default = true
}

variable "allowed_network_rules" {
  type    = list(string)
  default = []
}

variable "blocked_network_rules" {
  type    = list(string)
  default = []
}

variable "allowed_api_integrations" {
  type    = list(string)
  default = []
}

variable "blocked_api_integrations" {
  type    = list(string)
  default = []
}

variable "comment" {
  type     = string
  default  = null
  nullable = true
}

variable "snowsql_connection" {
  description = "Snow CLI connection profile name to use for local-exec commands."
  type        = string
  default     = null
  nullable    = true
}

locals {
  connection_flag = (
    var.snowsql_connection == null || try(trimspace(var.snowsql_connection), "") == ""
    ? ""
    : format(" -c %s", trimspace(var.snowsql_connection))
  )

  legacy_integration = (
    var.name == null || try(trimspace(var.name), "") == "" ? {} : {
      trimspace(var.name) = {
        enabled                  = var.enabled
        allowed_network_rules    = var.allowed_network_rules
        blocked_network_rules    = var.blocked_network_rules
        allowed_api_integrations = var.allowed_api_integrations
        blocked_api_integrations = var.blocked_api_integrations
        comment                  = var.comment
      }
    }
  )

  resolved_integrations = length(var.external_access_integrations) > 0 ? var.external_access_integrations : local.legacy_integration

  integration_payloads = {
    for name, cfg in local.resolved_integrations : trimspace(name) => {
      enabled                  = coalesce(try(cfg.enabled, null), var.enabled)
      allowed_network_rules    = [for v in coalesce(try(cfg.allowed_network_rules, null), var.allowed_network_rules) : trimspace(v) if trimspace(v) != ""]
      blocked_network_rules    = [for v in coalesce(try(cfg.blocked_network_rules, null), var.blocked_network_rules) : trimspace(v) if trimspace(v) != ""]
      allowed_api_integrations = [for v in coalesce(try(cfg.allowed_api_integrations, null), var.allowed_api_integrations) : trimspace(v) if trimspace(v) != ""]
      blocked_api_integrations = [for v in coalesce(try(cfg.blocked_api_integrations, null), var.blocked_api_integrations) : trimspace(v) if trimspace(v) != ""]
      comment                  = try(cfg.comment, var.comment)
    }
  }

  create_sql = {
    for name, cfg in local.integration_payloads : name => join("\n", concat(
      ["USE ROLE ACCOUNTADMIN;"],
      [format("CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION %s", name)],
      length(cfg.allowed_network_rules) == 0 ? [] : [format("  ALLOWED_NETWORK_RULES = (%s)", join(", ", cfg.allowed_network_rules))],
      length(cfg.blocked_network_rules) == 0 ? [] : [format("  BLOCKED_NETWORK_RULES = (%s)", join(", ", cfg.blocked_network_rules))],
      length(cfg.allowed_api_integrations) == 0 ? [] : [format("  ALLOWED_API_INTEGRATIONS = (%s)", join(", ", [for v in cfg.allowed_api_integrations : format("'%s'", replace(v, "'", "''"))]))],
      length(cfg.blocked_api_integrations) == 0 ? [] : [format("  BLOCKED_API_INTEGRATIONS = (%s)", join(", ", [for v in cfg.blocked_api_integrations : format("'%s'", replace(v, "'", "''"))]))],
      [format("  ENABLED = %s", cfg.enabled ? "TRUE" : "FALSE")],
      cfg.comment == null || trimspace(cfg.comment) == "" ? [] : [format("  COMMENT = '%s'", replace(cfg.comment, "'", "''"))],
      [";"]
    ))
  }

  drop_sql = {
    for name in keys(local.integration_payloads) : name => format("USE ROLE ACCOUNTADMIN;\nDROP INTEGRATION IF EXISTS %s;", name)
  }
}

resource "null_resource" "external_access_integration" {
  for_each = local.integration_payloads

  triggers = {
    name            = each.key
    payload         = local.create_sql[each.key]
    drop            = local.drop_sql[each.key]
    connection_flag = local.connection_flag
  }

  # requires bash (macOS/Linux/WSL/Git Bash); SQL passed via env var to handle quotes and newlines
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "snow sql${self.triggers.connection_flag} -q \"$SNOW_SQL\""
    environment = {
      SNOW_SQL = self.triggers.payload
    }
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    command     = "snow sql${self.triggers.connection_flag} -q \"$SNOW_SQL\""
    environment = {
      SNOW_SQL = self.triggers.drop
    }
  }
}

output "external_access_integration_names" {
  value       = [for name in keys(local.integration_payloads) : name]
  description = "List of external access integration names managed via Snow CLI."
}
