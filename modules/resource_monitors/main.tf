variable "resource_monitors" {
  type = map(object({
    credit_quota                = number
    frequency                   = optional(string)
    start_timestamp             = optional(string)
    notify_triggers             = optional(list(number))
    suspend_trigger             = optional(number)
    suspend_immediately_trigger = optional(number)
    notify_users                = optional(list(string))
  }))
  default = {}
}

variable "name" {
  type     = string
  default  = null
  nullable = true
}

variable "credit_quota" {
  type     = number
  default  = null
  nullable = true
}

variable "frequency" {
  type     = string
  default  = null
  nullable = true
}

variable "start_timestamp" {
  type     = string
  default  = null
  nullable = true
}

locals {
  explicit_resource_monitors = {
    for monitor_name, cfg in var.resource_monitors : trimspace(monitor_name) => {
      credit_quota                = cfg.credit_quota
      frequency                   = try(cfg.frequency, null)
      start_timestamp             = try(cfg.start_timestamp, null)
      notify_triggers             = try(cfg.notify_triggers, [])
      suspend_trigger             = try(cfg.suspend_trigger, null)
      suspend_immediately_trigger = try(cfg.suspend_immediately_trigger, null)
      notify_users                = try(cfg.notify_users, [])
    }
    if trimspace(monitor_name) != ""
  }

  legacy_resource_monitor = (
    var.name == null || try(trimspace(var.name), "") == "" || var.credit_quota == null
    ) ? {} : {
    trimspace(var.name) = {
      credit_quota                = var.credit_quota
      frequency                   = var.frequency
      start_timestamp             = var.start_timestamp
      notify_triggers             = []
      suspend_trigger             = null
      suspend_immediately_trigger = null
      notify_users                = []
    }
  }

  resolved_resource_monitors = length(local.explicit_resource_monitors) > 0 ? local.explicit_resource_monitors : local.legacy_resource_monitor

  legacy_frequency_default = coalesce(var.frequency, "MONTHLY")

  default_start_timestamp = (
    try(trimspace(var.start_timestamp), "") != "" ?
    try(trimspace(var.start_timestamp), "") :
    formatdate("YYYY-MM-DD HH:mm", timeadd(timestamp(), "24h"))
  )
}

resource "snowflake_resource_monitor" "this" {
  for_each = local.resolved_resource_monitors

  name         = each.key
  credit_quota = each.value.credit_quota
  frequency    = coalesce(each.value.frequency, local.legacy_frequency_default)
  start_timestamp = (
    try(trimspace(each.value.start_timestamp), "") != "" ?
    try(trimspace(each.value.start_timestamp), "") :
    local.default_start_timestamp
  )

  notify_triggers             = each.value.notify_triggers
  suspend_trigger             = each.value.suspend_trigger
  suspend_immediately_trigger = each.value.suspend_immediately_trigger
  notify_users                = each.value.notify_users
}

output "resource_monitor_names" {
  value = { for monitor_name, monitor in snowflake_resource_monitor.this : monitor_name => monitor.name }
}

output "resource_monitor_name" {
  value = try(values(snowflake_resource_monitor.this)[0].name, null)
}
