variable "name" { type = string }
variable "comment" {
  type    = string
  default = null
}
variable "data_retention_time_in_days" {
  type    = number
  default = 1
}

resource "snowflake_database" "this" {
  name                        = var.name
  data_retention_time_in_days = var.data_retention_time_in_days
  comment                     = var.comment

  lifecycle { prevent_destroy = true }
}

output "database_name" { value = snowflake_database.this.name }
