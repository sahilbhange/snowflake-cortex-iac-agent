locals {
  legacy_integration = (
    var.integration_name == null || try(trimspace(var.integration_name), "") == "" ? {} : {
      trimspace(var.integration_name) = {
        enabled                  = var.integration_enabled
        allowed_network_rules    = var.integration_allowed_network_rules
        blocked_network_rules    = var.integration_blocked_network_rules
        allowed_api_integrations = var.integration_allowed_api_integrations
        blocked_api_integrations = var.integration_blocked_api_integrations
        comment                  = var.integration_comment
      }
    }
  )

  resolved_integrations = length(var.external_access_integrations) > 0 ? var.external_access_integrations : local.legacy_integration
}

module "external_access_integrations" {
  count     = var.enable_external_access_integrations ? 1 : 0
  source    = "../../../../modules/external_access_integrations"

  external_access_integrations = { for name, cfg in local.resolved_integrations : trimspace(name) => cfg }
  snowsql_connection           = var.snowsql_connection
  name                         = var.integration_name
  enabled                      = var.integration_enabled
  allowed_network_rules        = var.integration_allowed_network_rules
  blocked_network_rules        = var.integration_blocked_network_rules
  allowed_api_integrations     = var.integration_allowed_api_integrations
  blocked_api_integrations     = var.integration_blocked_api_integrations
  comment                      = var.integration_comment
}

