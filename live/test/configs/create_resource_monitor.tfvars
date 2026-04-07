enable_resource_monitor = true

resource_monitors = {
  RM_MONTHLY_LIMIT = {
    credit_quota                = 500
    frequency                   = "MONTHLY"
    notify_triggers             = [75, 90, 100]
    suspend_trigger             = 100
    suspend_immediate_trigger = 110
    # start_timestamp = "2025-10-03 15:00"  # make sure to set a future date/timestamp
  }

  RM_DAILY_LIMIT = {
    credit_quota                = 30
    frequency                   = "DAILY"
    notify_triggers             = [75, 90, 100]
    suspend_trigger             = 100
    suspend_immediate_trigger = 110
    # start_timestamp = "2025-10-02 19:00"  # make sure to set a future date/timestamp
  }
}
