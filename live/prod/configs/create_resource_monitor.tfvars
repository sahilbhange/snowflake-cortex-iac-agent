enable_resource_monitor = true

resource_monitors = {
  RM_MONTHLY_LIMIT = {
    credit_quota = 500
    frequency    = "MONTHLY"
    # start_timestamp = "2025-10-03 15:00"  # make sure to set a future date/timestamp
  }

  RM_DAILY_LIMIT = {
    credit_quota = 30
    frequency    = "DAILY"
    # start_timestamp = "2025-10-02 19:00"  # make sure to set a future date/timestamp
  }
}
