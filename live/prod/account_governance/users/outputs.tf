output "user_names" {
  value       = keys(var.users)
  description = "List of user identifiers managed by this stack."
}

