Usage

- Define configs for stages  
  - [create_schema.tfvars](../../configs/create_schema.tfvars)
  

- `cd live/test/workloads/schemas`
- `terraform init -upgrade`
- Plan/apply with shared connection vars and schema config:
  - `terraform plan  -var-file=../../account.auto.tfvars -var-file=../../configs/create_schema.tfvars`
  - `terraform apply -var-file=../../account.auto.tfvars -var-file=../../configs/create_schema.tfvars -auto-approve`

Inputs

- Connection: `organization_name`, `account_name`, `provisioning_user`, `private_key_path`, `query_tag`
- Schemas: use new `schemas` map (key = schema name) with optional `database`/`comment`; legacy single `schema_*` variables still accepted
