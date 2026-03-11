# Network Rules Stack


Usage
- Define configs for stages  
  - [create_network_rules.tfvars](../../configs/create_network_rules.tfvars)
  

- `cd live/prod/platform/network_rules`
- `terraform init -upgrade`
- Plan/apply with shared connection vars and the network rule config:
  - `terraform plan  -var-file=../../account.auto.tfvars -var-file=../../configs/create_network_rules.tfvars`
  - `terraform apply -var-file=../../account.auto.tfvars -var-file=../../configs/create_network_rules.tfvars -auto-approve`

Inputs

- Connection: `organization_name`, `account_name`, `provisioning_user`, `private_key_path`, `query_tag`, `accountadmin_role`
- Network rules: preferred `network_rules` map (key = rule name) specifying `database`, `schema`, `type`, `mode`, `value_list`, optional `comment`. Legacy single `network_rule_*` variables remain available.

Notes
- Creating network rules requires ACCOUNTADMIN (or a role with equivalent privileges).
- Value lists are de-duplicated and trimmed automatically.
- Provider preview `snowflake_network_rule_resource` is enabled in this stack; leave it on while Terraform manages network rules.
