Usage

- cd to this folder and initialize:
  - `terraform init -upgrade`
- Plan/apply the role using the shared config from two levels up:
  - `terraform plan  -var-file=../../account.auto.tfvars -var-file=../../configs/create_role.tfvars`
  - `terraform apply -var-file=../../account.auto.tfvars -var-file=../../configs/create_role.tfvars -auto-approve`

Inputs

- Connection: `organization_name`, `account_name`, `provisioning_user`, `private_key_path`, `query_tag`
- Role: `role_name`, `role_comment`, `role_parent_roles`
