# Database Rename Utility

This stack orchestrates one-off database renames in Snowflake while keeping Terraform state aligned.

## How it works

- Declare rename operations in `rename_requests` (see [`live/test/configs/rename_database.tfvars.json`](../../configs/rename_database.tfvars.json)) and flip `"execute": true` for the entry you want to run.
- `null_resource.rename_database` issues the SnowSQL `ALTER DATABASE` command via SnowSQL.
- The stack surfaces the matching `terraform state mv` and `terraform import` hints so Terraform state stays in sync after the rename.

## Running the rename stack

Run the stack from Windows cmd.exe (carets continue the command and the inner double quotes must be escaped):

```cmd
cd \live\test\platform\database_rename

terraform init

terraform plan ^
  -target="null_resource.rename_database[\"sample_db_swap\"]" ^
  -var-file=..\..\account.auto.tfvars ^
  -var-file=..\..\configs\rename_database.tfvars.json

terraform apply ^
  -target="null_resource.rename_database[\"sample_db_swap\"]" ^
  -var-file=..\..\account.auto.tfvars ^
  -var-file=..\..\configs\rename_database.tfvars.json
```

## State alignment

After the SnowSQL rename succeeds:

1. Change into `live/test/platform/databases`.
    ```cmd
    cd live/test/platform/databases
    ```
2. Run `scripts/rename_database_state.ps1` to preview (and optionally execute with `-Apply`) the `terraform state mv`. The script also prints the matching `terraform import` command. You can either execute the script with `-Apply` or run the commands manually. Alternatively, run `scripts\run_rename_state.cmd <rename_id>` from any location to automate the database stack steps (it copies the tfvars, performs the move/remove/import, and cleans up).
3. Update [`live/test/configs/create_database.tfvars`](../../configs/create_database.tfvars) so the `databases` map references the new key (for example `TF_SAMPLE_DB_NEW`) and removes the old name.
4. If you plan to run the commands manually, copy the shared tfvars into the databases directory so Terraform can read them during the import:

    ```cmd
    copy ..\..\configs\create_database.tfvars terraform.tfvars
    copy ..\..\account.auto.tfvars .
    ```

5. Run the state move and import commands to rebind Terraform state to the renamed database:

    ***Update move commands with old and renamed database***
    ```cmd

    terraform state mv ^
      "module.database[\"TF_SAMPLE_DB_OLD\"].snowflake_database.this" ^
      "module.database[\"TF_SAMPLE_DB_NEW\"].snowflake_database.this"

    terraform state rm ^
      "module.database[\"TF_SAMPLE_DB_NEW\"].snowflake_database.this"

    terraform import ^
      "module.database[\"TF_SAMPLE_DB_NEW\"].snowflake_database.this" ^
      TF_SAMPLE_DB_NEW
    ```

6. Delete the temporary tfvars copies once the import succeeds:

    ```cmd
    del terraform.tfvars
    del account.auto.tfvars
    ```

7. Set `"execute": false` (or remove the entry) in [`live/test/configs/rename_database.tfvars.json`](../../configs/rename_database.tfvars.json) so future applies do nothing.

8. Run `terraform plan` in `live/test/platform/databases` to confirm zero drift.
    ```cmd
      terraform apply -var-file=../../account.auto.tfvars -var-file=../../configs/create_database.tfvars -auto-approve
    ```

## Variables

- `rename_requests`: Map describing each rename (from/to, optional overrides, etc.).
- `default_snowsql_connection`: Fallback SnowSQL connection profile name (defaults to `null`).
- `snowsql_binary_path`: SnowSQL executable to call; defaults to `snowsql`.
- Standard provider inputs (`organization_name`, `account_name`, `provisioning_user`, `private_key_path`, `query_tag`, `sysadmin_role`).

## Outputs

- `rename_commands`: SnowSQL command executed per rename request.
- `rename_state_moves`: Suggested `terraform state mv` source/destination pairs for the database module.

## Safety checks

- Requests with `execute = false` are ignored.
- Command triggers hash the SQL and CLI arguments so any change forces the resource to rerun.
- SQL identifiers are quoted to preserve case-sensitive database names.

## Recommended workflow

1. Stage the rename entry in `rename_database.tfvars.json` with `execute = true`.
2. Run `terraform plan` in this stack to review the SnowSQL command and state hints.
3. Apply the rename (targeted `terraform apply`).
4. Run `scripts/rename_database_state.ps1` to perform the state move (optionally with `-Apply`).
5. Copy the shared tfvars (or export equivalent environment variables), run the manual `terraform state mv` / `terraform import`, and clean up the temporary files. You can instead run `scripts\run_rename_state.cmd <rename_id>` to perform those steps automatically.
6. Set `execute = false` (or remove the entry) and re-run `terraform plan` in `live/test/platform/databases`.

## Cleanup

Remove completed entries from the rename map so the SnowSQL command will not rerun on the next apply.

## Smoke tests

1. **Dry run**: Leave `execute = false` and run `terraform plan` to confirm nothing executes.
2. **Single rename**: Enable one entry, run the targeted apply, perform the state move/import, and verify the database shows up with the new name and no drift.
3. **State mismatch guard**: Skip the state move/import deliberately, run `terraform plan` in `platform/databases`, and observe that Terraform wants to recreate the database?highlighting why the state steps are required.


