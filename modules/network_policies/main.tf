variable "network_policies" {
  description = "Map of network policies to manage (key = policy name)."
  type = map(object({
    allowed_ip_list           = optional(list(string), [])
    blocked_ip_list           = optional(list(string), [])
    allowed_network_rule_list = optional(list(string), [])
    blocked_network_rule_list = optional(list(string), [])
    comment                   = optional(string)
  }))
  default = {}
}

variable "name" {
  type     = string
  default  = null
  nullable = true
}

variable "allowed_ip_list" {
  type    = list(string)
  default = []
}

variable "blocked_ip_list" {
  type    = list(string)
  default = []
}

variable "allowed_network_rule_list" {
  type    = list(string)
  default = []
}

variable "blocked_network_rule_list" {
  type    = list(string)
  default = []
}

variable "comment" {
  type     = string
  default  = null
  nullable = true
}

locals {
  explicit_policies = {
    for policy_name, cfg in var.network_policies : trimspace(policy_name) => {
      allowed_ip_list           = distinct([for v in cfg.allowed_ip_list : trimspace(v)])
      blocked_ip_list           = distinct([for v in cfg.blocked_ip_list : trimspace(v)])
      allowed_network_rule_list = distinct([for v in cfg.allowed_network_rule_list : trimspace(v)])
      blocked_network_rule_list = distinct([for v in cfg.blocked_network_rule_list : trimspace(v)])
      comment                   = try(cfg.comment, var.comment)
    }
    if trimspace(policy_name) != ""
  }

  legacy_policy = (
    var.name == null || try(trimspace(var.name), "") == "" ? {} : {
      trimspace(var.name) = {
        allowed_ip_list           = distinct([for v in var.allowed_ip_list : trimspace(v)])
        blocked_ip_list           = distinct([for v in var.blocked_ip_list : trimspace(v)])
        allowed_network_rule_list = distinct([for v in var.allowed_network_rule_list : trimspace(v)])
        blocked_network_rule_list = distinct([for v in var.blocked_network_rule_list : trimspace(v)])
        comment                   = var.comment
      }
    }
  )

  resolved_policies = length(var.network_policies) > 0 ? local.explicit_policies : local.legacy_policy
}

resource "snowflake_network_policy" "this" {
  for_each = local.resolved_policies

  name                      = each.key
  allowed_ip_list           = each.value.allowed_ip_list
  blocked_ip_list           = each.value.blocked_ip_list
  allowed_network_rule_list = each.value.allowed_network_rule_list
  blocked_network_rule_list = each.value.blocked_network_rule_list
  comment                   = each.value.comment
}

output "network_policy_names" {
  value       = { for policy_name, policy in snowflake_network_policy.this : policy_name => policy.name }
  description = "Map of network policy names managed by this module."
}

output "network_policy_name" {
  value = length(snowflake_network_policy.this) == 0 ? null : (
    var.name != null && try(trimspace(var.name), "") != "" && try(contains(keys(snowflake_network_policy.this), trimspace(var.name)), false)
    ? snowflake_network_policy.this[trimspace(var.name)].name
    : values(snowflake_network_policy.this)[0].name
  )
  description = "Legacy single network policy output."
}
