# Why Terraform Cannot Rename Snowflake Databases In-Place

Terraform maps resources by ID and expects providers to support updates in-place. The Snowflake provider marks the `name` argument on `snowflake_database` as `ForceNew`, so any change to the database name forces Terraform to destroy and recreate the resource.

The provider cannot issue `ALTER DATABASE ... RENAME TO ...` because Snowflake exposes no API that allows Terraform to treat the rename as an update while keeping the same resource identity. Without first-class rename support, Terraform sees a different `for_each` key and concludes the old database must be dropped and a new one created.

Manual renames also break the Terraform state. If the Snowflake name changes outside Terraform, the stored object ID no longer matches reality. You must run `terraform state mv` (or re-import) to re-bind the state to the renamed database and avoid an unintended destroy-recreate cycle.

Because of these constraints, renames are handled via the dedicated SnowSQL workflow documented in this directory: you rename the database yourself, then realign Terraform state. This keeps the process repeatable while working within Terraform's resource model and Snowflake's provider limitations.
