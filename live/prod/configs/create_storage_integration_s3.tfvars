enable_storage_integration_s3 = true

storage_integrations = {
  AWS_DEV_S3_INT = {
    allowed_locations = [
      "s3://example.terraform.s3/"
    ]
    enabled           = true # matches ENABLED = true
    comment           = ""   # or omit if you don’t need one
    blocked_locations = []   # optional; omit if you don’t use it
  }

  AWS_DEV_S3_INT_TEST2 = {
    allowed_locations = [
      "s3://example.terraform.s3/"
    ]
    enabled           = true # matches ENABLED = true
    comment           = ""   # or omit if you don’t need one
    blocked_locations = []   # optional; omit if you don’t use it
  }

}
