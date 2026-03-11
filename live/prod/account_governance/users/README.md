Usage

- cd to this folder and initialize:
  - `terraform init -upgrade`
- Plan/apply users using the shared config from two levels up:
  - `terraform plan  -var-file=../../account.auto.tfvars -var-file=../../configs/create_users.tfvars`
  - `terraform apply -var-file=../../account.auto.tfvars -var-file=../../configs/create_users.tfvars -auto-approve`

Inputs

- Connection: `organization_name`, `account_name`, `provisioning_user`, `private_key_path`, `query_tag`
- Users: `users` map with attributes; optional per-user overrides like `workspace_schema_additional_privileges` to extend default schema grants
