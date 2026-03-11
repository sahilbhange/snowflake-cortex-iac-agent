variable "storage_integrations" {
  description = "Map of storage integrations to manage (key = integration name)."
  type = map(object({
    allowed_locations = list(string)
    blocked_locations = optional(list(string))
    aws_role_arn      = string
    enabled           = optional(bool)
    comment           = optional(string)
  }))
  default = {}
}

variable "name" {
  type     = string
  default  = null
  nullable = true
}

variable "allowed_locations" {
  type     = list(string)
  default  = []
}

variable "blocked_locations" {
  type     = list(string)
  default  = []
}

variable "aws_role_arn" {
  type     = string
  default  = null
  nullable = true
}

variable "enabled" {
  type     = bool
  default  = null
  nullable = true
}

variable "comment" {
  type     = string
  default  = null
  nullable = true
}

locals {
  explicit_integrations = {
    for integration_name, cfg in var.storage_integrations : trimspace(integration_name) => {
      allowed_locations = distinct([for v in cfg.allowed_locations : trimspace(v)])
      blocked_locations = distinct([for v in try(cfg.blocked_locations, []) : trimspace(v)])
      aws_role_arn      = try(coalesce(try(cfg.aws_role_arn, null), var.aws_role_arn), null)
      enabled           = try(cfg.enabled, var.enabled)
      comment           = try(cfg.comment, var.comment)
    }
    if trimspace(integration_name) != ""
  }

 legacy_integration = (
    var.name == null || try(trimspace(var.name), "") == "" ? {} : {
      trimspace(var.name) = {
        allowed_locations = distinct([for v in var.allowed_locations : trimspace(v)])
        blocked_locations = distinct([for v in var.blocked_locations : trimspace(v)])
        aws_role_arn      = var.aws_role_arn
        enabled           = coalesce(var.enabled, true)
        comment           = var.comment
      }
    }
  )

  resolved_integrations = length(var.storage_integrations) > 0 ? local.explicit_integrations : local.legacy_integration
}

resource "snowflake_storage_integration" "this" {
  for_each = local.resolved_integrations

  name                      = each.key
  storage_provider          = "S3"
  enabled                   = coalesce(each.value.enabled, true)
  storage_allowed_locations = each.value.allowed_locations
  storage_blocked_locations = each.value.blocked_locations
  storage_aws_role_arn      = each.value.aws_role_arn
  comment                   = each.value.comment
}

output "storage_integration_names" {
  value       = { for name, integration in snowflake_storage_integration.this : name => integration.name }
  description = "Map of storage integration names managed by this module."
}

output "storage_integration_aws_iam_user_arns" {
  value       = { for name, integration in snowflake_storage_integration.this : name => integration.storage_aws_iam_user_arn }
  description = "Map of AWS IAM user ARNs generated for each integration."
}

output "storage_integration_aws_external_ids" {
  value       = { for name, integration in snowflake_storage_integration.this : name => integration.storage_aws_external_id }
  description = "Map of AWS external IDs generated for each integration."
}

output "storage_integration_name" {
  value = length(snowflake_storage_integration.this) == 0 ? null : (
    var.name != null && try(trimspace(var.name), "") != "" && try(contains(keys(snowflake_storage_integration.this), trimspace(var.name)), false)
      ? snowflake_storage_integration.this[trimspace(var.name)].name
      : values(snowflake_storage_integration.this)[0].name
  )
  description = "Legacy single integration name output."
}

output "storage_aws_iam_user_arn" {
  value = length(snowflake_storage_integration.this) == 0 ? null : (
    var.name != null && try(trimspace(var.name), "") != "" && try(contains(keys(snowflake_storage_integration.this), trimspace(var.name)), false)
      ? snowflake_storage_integration.this[trimspace(var.name)].storage_aws_iam_user_arn
      : values(snowflake_storage_integration.this)[0].storage_aws_iam_user_arn
  )
  description = "Legacy single AWS IAM user ARN output."
}

output "storage_aws_external_id" {
  value = length(snowflake_storage_integration.this) == 0 ? null : (
    var.name != null && try(trimspace(var.name), "") != "" && try(contains(keys(snowflake_storage_integration.this), trimspace(var.name)), false)
      ? snowflake_storage_integration.this[trimspace(var.name)].storage_aws_external_id
      : values(snowflake_storage_integration.this)[0].storage_aws_external_id
  )
  description = "Legacy single AWS external ID output."
}
