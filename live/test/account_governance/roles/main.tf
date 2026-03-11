locals {
  explicit_roles = {
    for name, cfg in var.roles : trimspace(name) => {
      comment       = try(cfg.comment, null)
      parent_roles  = try(cfg.parent_roles, [])
      granted_roles = try(cfg.granted_roles, [])
    }
    if trimspace(name) != ""
  }

  legacy_role = var.role_name == null ? {} : {
    trimspace(var.role_name) = {
      comment       = var.role_comment
      parent_roles  = var.role_parent_roles
      granted_roles = []
    }
  }

  resolved_roles = length(var.roles) > 0 ? local.explicit_roles : local.legacy_role
}

module "role" {
  for_each  = var.enable_role ? local.resolved_roles : {}
  source    = "../../../../modules/roles"
  providers = { snowflake = snowflake.secadmin }

  name          = each.key
  comment       = each.value.comment
  parent_roles  = each.value.parent_roles
  granted_roles = each.value.granted_roles
}
