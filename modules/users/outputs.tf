output "created_user_names" { value = [for k, v in snowflake_user.this : v.name] }
