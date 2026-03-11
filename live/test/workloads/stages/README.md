Usage
- Define configs for stages  
  - [create_stage_s3.tfvars](../../configs/create_stage_s3.tfvars)
  
- `cd live/test/workloads/stages`
- `terraform init -upgrade`
- Plan/apply with shared connection vars and stage config:
  - `terraform plan  -var-file=../../account.auto.tfvars -var-file=../../configs/create_stage_s3.tfvars`
  - `terraform apply -var-file=../../account.auto.tfvars -var-file=../../configs/create_stage_s3.tfvars -auto-approve`

Inputs

- Connection: `organization_name`, `account_name`, `provisioning_user`, `private_key_path`, `query_tag`
- Stages: `stages` map (key = stage name) with optional overrides (`database`, `schema`, `url`, `storage_integration`, `comment`); legacy single `stage_*` inputs still supported

Notes

- Ensure the required storage integration exists (managed via the platform stack) and pass its name via `stage_storage_integration`.
