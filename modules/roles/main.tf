variable "name" { type = string }

variable "comment" {
  type    = string
  default = null
}

variable "parent_roles" {
  type    = list(string)
  default = []
}

variable "granted_roles" {
  type    = list(string)
  default = []
}

resource "snowflake_account_role" "this" {
  name    = var.name
  comment = var.comment
}

resource "snowflake_grant_account_role" "to_parent_roles" {
  for_each = toset(var.parent_roles)

  role_name        = snowflake_account_role.this.name
  parent_role_name = each.value
}

resource "snowflake_grant_account_role" "granted_roles" {
  for_each = toset(var.granted_roles)

  role_name        = each.value
  parent_role_name = snowflake_account_role.this.name
}
