locals {
  filtered_requests = {
    for id, req in var.rename_requests :
    id => req
    if try(req.execute, true)
  }

  pending_requests = {
    for id, req in local.filtered_requests :
    id => {
      from       = trimspace(req.from)
      to         = trimspace(req.to)
      connection_flag = (
        trimspace(try(req.snowsql_connection, coalesce(var.default_snowsql_connection, ""))) != ""
        ? format("-c %s", trimspace(try(req.snowsql_connection, coalesce(var.default_snowsql_connection, ""))))
        : ""
      )
      state_from  = trimspace(try(req.state_from_key, req.from))
      state_to    = trimspace(try(req.state_to_key, req.to))
      module_addr = trimspace(try(req.module_address, "module.database"))
    }
  }

  sql_statements = {
    for id, req in local.pending_requests :
    id => format(
      "ALTER DATABASE \"%s\" RENAME TO \"%s\";",
      replace(req.from, "\"", "\"\""),
      replace(req.to, "\"", "\"\"")
    )
  }

  state_moves = {
    for id, req in local.pending_requests :
    id => {
      from = format("%s[\"%s\"].snowflake_database.this", req.module_addr, replace(req.state_from, "\"", "\\\""))
      to   = format("%s[\"%s\"].snowflake_database.this", req.module_addr, replace(req.state_to, "\"", "\\\""))
    }
  }
}

resource "null_resource" "rename_database" {
  for_each = local.pending_requests

  triggers = {
    from            = upper(each.value.from)
    to              = upper(each.value.to)
    connection_flag = each.value.connection_flag
    sql             = local.sql_statements[each.key]
  }

  # requires bash (macOS/Linux/WSL/Git Bash); SQL passed via env var to handle quotes safely
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "snow sql ${self.triggers.connection_flag} -q \"$SNOW_SQL\""
    environment = {
      SNOW_SQL = self.triggers.sql
    }
  }
}

output "rename_state_moves" {
  description = "Suggested terraform state mv commands keyed by rename identifier."
  value       = local.state_moves
}

output "rename_commands" {
  description = "Snow CLI commands that will be executed for each rename request."
  value = {
    for id, req in local.pending_requests :
    id => "snow sql ${req.connection_flag} -q '${local.sql_statements[id]}'"
  }
}
