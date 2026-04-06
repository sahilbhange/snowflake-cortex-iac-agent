variable "service_users" {
  description = "Map of service users to create (key = user name). Uses snowflake_service_user (TYPE=SERVICE) — key-pair auth only, no interactive login."
  type = map(object({
    login_name        = optional(string)
    display_name      = optional(string)
    disabled          = optional(bool, false)
    default_role      = optional(string)
    default_warehouse = optional(string)
    rsa_public_key    = optional(string)
    rsa_public_key_2  = optional(string)
    comment           = optional(string)
    roles             = optional(list(string), [])
  }))
  default = {}
}

locals {
  user_role_pairs = flatten([
    for uname, u in var.service_users : [
      for r in u.roles : {
        user = uname
        role = r
      }
    ]
  ])
}

resource "snowflake_service_user" "this" {
  for_each = var.service_users

  name       = each.key
  login_name = coalesce(each.value.login_name, lower(each.key))
  display_name = coalesce(
    each.value.display_name,
    each.key
  )

  disabled          = each.value.disabled
  default_role      = each.value.default_role
  default_warehouse = each.value.default_warehouse
  rsa_public_key    = each.value.rsa_public_key
  rsa_public_key_2  = each.value.rsa_public_key_2
  comment           = each.value.comment

  lifecycle {
    ignore_changes = [
      rsa_public_key,
      rsa_public_key_2,
    ]
  }
}

resource "snowflake_grant_account_role" "service_user_roles" {
  for_each = { for p in local.user_role_pairs : "${p.user}|${p.role}" => p }

  role_name = each.value.role
  user_name = snowflake_service_user.this[each.value.user].name
}

output "service_user_names" {
  value       = { for k, v in snowflake_service_user.this : k => v.name }
  description = "Map of service user names managed by this module."
}
