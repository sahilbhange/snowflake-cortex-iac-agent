Usage

- `cd live/test/platform/resource_monitors`
- `terraform init -upgrade`
- Plan/apply with shared connection vars and resource monitor config:
  - `terraform plan  -var-file=../../account.auto.tfvars -var-file=../../configs/create_resource_monitor.tfvars`
  - `terraform apply -var-file=../../account.auto.tfvars -var-file=../../configs/create_resource_monitor.tfvars -auto-approve`

Inputs

- Connection: `organization_name`, `account_name`, `provisioning_user`, `private_key_path`, `query_tag`, `accountadmin_role`
- Resource monitors: new `resource_monitors` map (key = name) with `credit_quota`, optional `frequency` / `start_timestamp`; legacy single `rm_*` inputs still accepted
