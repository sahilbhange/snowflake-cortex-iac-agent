variable "database" { type = string }
variable "name" { type = string }
variable "comment" {
  type    = string
  default = null
}

resource "snowflake_schema" "this" {
  database     = var.database
  name         = var.name
  comment      = var.comment
  is_transient = false
}

output "schema_fqn" { value = "${snowflake_schema.this.database}.${snowflake_schema.this.name}" }
