variable "users" {
  description = "Map of users to create (key = user name)"
  type = map(object({
    login_name               = optional(string)
    first_name               = optional(string)
    last_name                = optional(string)
    email                    = optional(string)
    disabled                 = optional(bool, false)
    default_role             = optional(string)
    default_warehouse        = optional(string)
    must_change_password     = optional(bool, false)
    rsa_public_key           = optional(string)
    comment                  = optional(string)
    display_name             = optional(string)
    roles                    = optional(list(string), [])
    workspace_schema_name    = optional(string)
    workspace_schema_additional_privileges = optional(list(string), [])
    create_workspace_schema  = optional(bool, true)
  }))
  default = {}
}

variable "workspace_schema_database" {
  description = "Database name for per-user workspace schemas. Leave null to disable schema creation."
  type        = string
  default     = null
}

variable "workspace_schema_comment" {
  description = "Optional comment applied to each workspace schema. If null a default comment is generated."
  type        = string
  default     = null
}

variable "workspace_schema_grant_roles" {
  description = "Roles that receive privileges on workspace schemas."
  type        = list(string)
  default     = []
}

variable "workspace_schema_grant_privileges" {
  description = "Privileges granted to workspace_schema_grant_roles on each workspace schema."
  type        = list(string)
  default     = []
}

locals {
  user_role_pairs = flatten([
    for uname, u in var.users : [
      for r in lookup(u, "roles", []) : {
        user = uname
        role = r
      }
    ]
  ])

  workspace_schema_inputs = var.workspace_schema_database == null ? {} : {
    for uname, u in var.users : uname => {
      schema_name = upper(
        replace(
          replace(
            replace(
              (
                try(trimspace(u.workspace_schema_name), "") != "" ?
                trimspace(u.workspace_schema_name) :
                uname
              ),
              " ", "_"
            ),
            "-", "_"
          ),
          ".", "_"
        )
      )
    }
    if try(u.create_workspace_schema, true)
  }

  workspace_schema_privileges = {
    for uname, u in var.users : uname => distinct([
      for priv in concat(
        var.workspace_schema_grant_privileges,
        try(u.workspace_schema_additional_privileges, [])
      ) : trimspace(priv)
      if trimspace(priv) != ""
    ])
  }

  workspace_schema_grant_pairs = flatten([
    for uname in keys(local.workspace_schema_inputs) : length(local.workspace_schema_privileges[uname]) == 0 ? [] : [
      for role in var.users[uname].roles : {
        key        = format("%s|%s", uname, role)
        user       = uname
        role       = role
        privileges = local.workspace_schema_privileges[uname]
      }
    ]
  ])
}

resource "snowflake_user" "this" {
  for_each = var.users

  name       = each.key
  login_name = coalesce(each.value.login_name, lower(each.key))
  display_name = (
    length(try(trimspace(each.value.display_name), "")) > 0 ?
    try(trimspace(each.value.display_name), "") :
    (
      length(
        try(
          trimspace(
            join(
              " ",
              compact([
                try(trimspace(each.value.first_name), ""),
                try(trimspace(each.value.last_name), "")
              ])
            )
          ),
          ""
        )
      ) > 0 ?
      try(
        trimspace(
          join(
            " ",
            compact([
              try(trimspace(each.value.first_name), ""),
              try(trimspace(each.value.last_name), "")
            ])
          )
        ),
        each.key
      ) :
      each.key
    )
  )

  first_name = lookup(each.value, "first_name", null)
  last_name  = lookup(each.value, "last_name", null)
  email      = lookup(each.value, "email", null)

  disabled             = lookup(each.value, "disabled", false)
  default_role         = lookup(each.value, "default_role", null)
  default_warehouse    = lookup(each.value, "default_warehouse", null)
  default_namespace    = contains(keys(local.workspace_schema_inputs), each.key) ? format("%s.%s", var.workspace_schema_database, local.workspace_schema_inputs[each.key].schema_name) : null
  must_change_password = lookup(each.value, "must_change_password", false)
  rsa_public_key       = lookup(each.value, "rsa_public_key", null)
  comment              = lookup(each.value, "comment", null)
}

resource "snowflake_schema" "workspace" {
  for_each = local.workspace_schema_inputs
  provider = snowflake.sysadmin

  database = var.workspace_schema_database
  name     = each.value.schema_name
  comment  = coalesce(var.workspace_schema_comment, format("Workspace schema for %s", snowflake_user.this[each.key].name))
}

resource "snowflake_grant_privileges_to_account_role" "workspace" {
  for_each = { for pair in local.workspace_schema_grant_pairs : pair.key => pair }
  provider = snowflake.sysadmin

  account_role_name = each.value.role
  privileges        = each.value.privileges

  on_schema {
    schema_name = format("%s.%s", var.workspace_schema_database, snowflake_schema.workspace[each.value.user].name)
  }
}

resource "snowflake_grant_account_role" "user_roles" {
  for_each = { for p in local.user_role_pairs : "${p.user}|${p.role}" => p }

  role_name = each.value.role
  user_name = snowflake_user.this[each.value.user].name
}
