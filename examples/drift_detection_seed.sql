-- Drift Detection Test Seed
-- Run these statements to create unmanaged objects in Snowflake,
-- then use $coco-iac-agent drift report to detect them.
-- Clean up after testing with the DROP statements at the bottom.

-- ============================================================
-- SCENARIO 1: Sales Team Workload (basic drift)
-- ============================================================
USE ROLE SECURITYADMIN;
CREATE ROLE IF NOT EXISTS SALES_ROLE COMMENT = 'Sales team - created manually outside Terraform';
GRANT ROLE SALES_ROLE TO ROLE SYSADMIN;

CREATE ROLE IF NOT EXISTS SALES_READ COMMENT = 'Read access for sales data - manual';
GRANT ROLE SALES_READ TO ROLE SYSADMIN;
GRANT ROLE SALES_READ TO ROLE SALES_ROLE;

USE ROLE SYSADMIN;
CREATE WAREHOUSE IF NOT EXISTS SALES_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'Sales warehouse - created manually';

CREATE SCHEMA IF NOT EXISTS ANALYTICS_DB.SALES_MART
  COMMENT = 'Sales mart - created outside Terraform';

USE ROLE SECURITYADMIN;
CREATE USER IF NOT EXISTS tsmith
  FIRST_NAME = 'Tom'
  LAST_NAME = 'Smith'
  EMAIL = 'tsmith@company.com'
  DEFAULT_ROLE = SALES_ROLE
  DEFAULT_WAREHOUSE = SALES_WH
  COMMENT = 'Manual user - not in Terraform';
GRANT ROLE SALES_ROLE TO USER tsmith;

-- ============================================================
-- SCENARIO 2: ETL/Data Engineering Workload
-- ============================================================
USE ROLE SECURITYADMIN;
CREATE ROLE IF NOT EXISTS ETL_ROLE COMMENT = 'Data engineering - ETL pipelines';
GRANT ROLE ETL_ROLE TO ROLE SYSADMIN;

CREATE ROLE IF NOT EXISTS RAW_WRITE COMMENT = 'Write access to RAW_DB';
GRANT ROLE RAW_WRITE TO ROLE SYSADMIN;
GRANT ROLE RAW_WRITE TO ROLE ETL_ROLE;

USE ROLE SYSADMIN;
CREATE WAREHOUSE IF NOT EXISTS ETL_WH
  WAREHOUSE_SIZE = 'SMALL'
  AUTO_SUSPEND = 120
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'ETL processing warehouse';

CREATE SCHEMA IF NOT EXISTS RAW_DB.INGESTION
  COMMENT = 'Landing zone for raw data ingestion';

CREATE SCHEMA IF NOT EXISTS ANALYTICS_DB.STAGING
  COMMENT = 'Staging area for transformations';
