locals {
  legacy_network_rule = (
    var.network_rule_name == null || try(trimspace(var.network_rule_name), "") == "" ? {} : {
      trimspace(var.network_rule_name) = {
        database   = var.network_rule_database
        schema     = var.network_rule_schema
        type       = coalesce(var.network_rule_type, "HOST_PORT")
        mode       = coalesce(var.network_rule_mode, "EGRESS")
        value_list = var.network_rule_value_list
        comment    = var.network_rule_comment
      }
    }
  )

  resolved_network_rules = length(var.network_rules) > 0 ? var.network_rules : local.legacy_network_rule
}

module "network_rules" {
  count     = var.enable_network_rules ? 1 : 0
  source    = "../../../../modules/network_rules"
  providers = { snowflake = snowflake.accountadmin }

  network_rules       = { for name, cfg in local.resolved_network_rules : trimspace(name) => cfg }
  name                = var.network_rule_name
  database            = var.network_rule_database
  schema              = var.network_rule_schema
  type                = var.network_rule_type
  mode                = var.network_rule_mode
  value_list          = var.network_rule_value_list
  comment             = var.network_rule_comment
}
