Usage
- Define configs for storage integration  
  - [create_storage_integration_s3.tfvars](../../configs/create_storage_integration_s3.tfvars)
  

- `cd live/test/platform/storage_integrations_s3`
- `terraform init -upgrade`
- Plan/apply with shared connection vars and integration config:
  - `terraform plan  -var-file=../../account.auto.tfvars -var-file=../../configs/create_storage_integration_s3.tfvars`
  - `terraform apply -var-file=../../account.auto.tfvars -var-file=../../configs/create_storage_integration_s3.tfvars -auto-approve`



Inputs

- Connection: `organization_name`, `account_name`, `provisioning_user`, `private_key_path`, `query_tag`, `accountadmin_role`
- Storage integrations: use `storage_integrations` map (key = integration name) to specify `allowed_locations`, optional `blocked_locations`, `aws_role_arn`, `enabled`, `comment`. Legacy `si_*` variables remain available for single integrations.

Notes

- Storage integrations require ACCOUNTADMIN privileges.
- Outputs include the integration name plus generated AWS IAM user ARN and external ID to share with the AWS team.
- Provider preview `snowflake_storage_integration_resource` stays enabled for Terraform management.
