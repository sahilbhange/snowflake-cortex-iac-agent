locals {
  legacy_integration = (
    var.si_name == null || try(trimspace(var.si_name), "") == "" ? {} : {
      trimspace(var.si_name) = {
        allowed_locations = var.si_allowed_locations
        blocked_locations = var.si_blocked_locations
        aws_role_arn      = try(coalesce(var.si_aws_role_arn, var.aws_role_arn), null)
        enabled           = var.si_enabled
        comment           = var.si_comment
      }
    }
  )

  raw_integrations = length(var.storage_integrations) > 0 ? var.storage_integrations : local.legacy_integration

  resolved_integrations = {
    for name, cfg in local.raw_integrations : trimspace(name) => merge(cfg, {
      aws_role_arn = try(coalesce(try(cfg.aws_role_arn, null), var.aws_role_arn), null)
    })
  }
}

module "storage_integration_s3" {
  count     = var.enable_storage_integration_s3 ? 1 : 0
  source    = "../../../../modules/storage_integration_s3"
  providers = { snowflake = snowflake.accountadmin }

  storage_integrations = local.resolved_integrations
  name                 = var.si_name
  allowed_locations    = var.si_allowed_locations
  blocked_locations    = var.si_blocked_locations
  aws_role_arn         = try(coalesce(var.si_aws_role_arn, var.aws_role_arn), null)
  enabled              = var.si_enabled
  comment              = var.si_comment
}
