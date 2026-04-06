locals {
  legacy_network_policy = (
    var.network_policy_name == null || try(trimspace(var.network_policy_name), "") == "" ? {} : {
      trimspace(var.network_policy_name) = {
        allowed_ip_list           = var.network_policy_allowed_ip_list
        blocked_ip_list           = var.network_policy_blocked_ip_list
        allowed_network_rule_list = var.network_policy_allowed_network_rule_list
        blocked_network_rule_list = var.network_policy_blocked_network_rule_list
        comment                   = var.network_policy_comment
      }
    }
  )

  resolved_network_policies = length(var.network_policies) > 0 ? var.network_policies : local.legacy_network_policy
}

module "network_policies" {
  count     = var.enable_network_policies ? 1 : 0
  source    = "../../../../modules/network_policies"
  providers = { snowflake = snowflake.accountadmin }

  network_policies          = { for name, cfg in local.resolved_network_policies : trimspace(name) => cfg }
  name                      = var.network_policy_name
  allowed_ip_list           = var.network_policy_allowed_ip_list
  blocked_ip_list           = var.network_policy_blocked_ip_list
  allowed_network_rule_list = var.network_policy_allowed_network_rule_list
  blocked_network_rule_list = var.network_policy_blocked_network_rule_list
  comment                   = var.network_policy_comment
}
