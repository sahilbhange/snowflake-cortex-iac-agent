locals {
  stage_outputs = var.enable_stage && length(module.stage) > 0 ? module.stage[0].stage_fqns : {}
}

output "stage_fqns" {
  value       = local.stage_outputs
  description = "Map of stage FQNs managed by this stack."
}

output "stage_fqn" {
  value = length(local.stage_outputs) == 0 ? null : (
    var.stage_name != null && try(trimspace(var.stage_name), "") != "" && try(contains(keys(local.stage_outputs), trimspace(var.stage_name)), false)
      ? local.stage_outputs[trimspace(var.stage_name)]
      : values(local.stage_outputs)[0]
  )
  description = "Legacy single stage FQN for backwards compatibility."
}
