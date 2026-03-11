Usage

- Define configs for stages  
  - [create_database.tfvars](../../configs/create_database.tfvars)
  
- cd to this folder and initialize:
  - `terraform init -upgrade`
- Plan/apply the database using the shared config from two levels up:
  - `terraform plan  -var-file=../../account.auto.tfvars -var-file=../../configs/create_database.tfvars`
  - `terraform apply -var-file=../../account.auto.tfvars -var-file=../../configs/create_database.tfvars -auto-approve`

Inputs

- Connection: `organization_name`, `account_name`, `provisioning_user`, `private_key_path`, `query_tag`
- Database: `database_name`, `database_comment`, `database_data_retention_days`
