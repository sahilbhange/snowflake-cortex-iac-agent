output "service_user_names" {
  value       = var.enable_service_users && length(module.service_users) > 0 ? module.service_users[0].service_user_names : {}
  description = "Map of service user names managed by this stack."
}
