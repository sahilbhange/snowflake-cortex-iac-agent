enable_stage = true

stages = {
  RAW_S3 = {
    database            = "RAW_DB"
    schema              = "LANDING"
    url                 = "s3://example-bucket/tf_test/"
    storage_integration = "AWS_DEV_S3_INT"
    comment             = "S3 external stage — RAW_DB.LANDING ingestion path"
  }
}
