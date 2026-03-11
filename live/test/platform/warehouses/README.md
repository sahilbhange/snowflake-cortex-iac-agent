Usage

- `cd live/test/platform/warehouses`
- `terraform init -upgrade`
- Plan/apply with shared connection vars (two levels up) and the warehouse config from `configs/`:
  - `terraform plan  -var-file=../../account.auto.tfvars -var-file=../../configs/create_warehouse.tfvars`
  - `terraform apply -var-file=../../account.auto.tfvars -var-file=../../configs/create_warehouse.tfvars -auto-approve`

Inputs

- Connection: `organization_name`, `account_name`, `provisioning_user`, `private_key_path`, `query_tag`
- Warehouses: map input `warehouses` (key = name) with optional overrides (`size`, suspend/resume, cluster counts, `comment`); legacy single `warehouse_*` variables still accepted
