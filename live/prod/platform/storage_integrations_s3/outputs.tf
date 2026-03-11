locals {
  integration_outputs = var.enable_storage_integration_s3 && length(module.storage_integration_s3) > 0 ? module.storage_integration_s3[0] : null
}

output "storage_integration_names" {
  value       = local.integration_outputs == null ? {} : local.integration_outputs.storage_integration_names
  description = "Map of storage integration names managed by this stack."
}

output "storage_integration_aws_iam_user_arns" {
  value       = local.integration_outputs == null ? {} : local.integration_outputs.storage_integration_aws_iam_user_arns
  description = "AWS IAM user ARNs generated for each integration."
}

output "storage_integration_aws_external_ids" {
  value       = local.integration_outputs == null ? {} : local.integration_outputs.storage_integration_aws_external_ids
  description = "AWS external IDs generated for each integration."
}

output "storage_integration_name" {
  value = local.integration_outputs == null ? null : (
    var.si_name != null && try(trimspace(var.si_name), "") != "" && try(contains(keys(local.integration_outputs.storage_integration_names), trimspace(var.si_name)), false)
    ? local.integration_outputs.storage_integration_names[trimspace(var.si_name)]
    : values(local.integration_outputs.storage_integration_names)[0]
  )
  description = "Legacy single integration name."
}

output "storage_aws_iam_user_arn" {
  value = local.integration_outputs == null ? null : (
    var.si_name != null && try(trimspace(var.si_name), "") != "" && try(contains(keys(local.integration_outputs.storage_integration_aws_iam_user_arns), trimspace(var.si_name)), false)
    ? local.integration_outputs.storage_integration_aws_iam_user_arns[trimspace(var.si_name)]
    : values(local.integration_outputs.storage_integration_aws_iam_user_arns)[0]
  )
  description = "Legacy single AWS IAM user ARN."
}

output "storage_aws_external_id" {
  value = local.integration_outputs == null ? null : (
    var.si_name != null && try(trimspace(var.si_name), "") != "" && try(contains(keys(local.integration_outputs.storage_integration_aws_external_ids), trimspace(var.si_name)), false)
    ? local.integration_outputs.storage_integration_aws_external_ids[trimspace(var.si_name)]
    : values(local.integration_outputs.storage_integration_aws_external_ids)[0]
  )
  description = "Legacy single AWS external ID."
}
