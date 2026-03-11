enable_warehouse = true

# One warehouse per functional role — isolates compute costs and enables per-team resource monitors
warehouses = {
  TRANSFORMER_WH = {
    size         = "XSMALL"
    auto_suspend = 60
    auto_resume  = true
  }
  ANALYST_WH = {
    size         = "XSMALL"
    auto_suspend = 60
    auto_resume  = true
  }
  ENGINEER_WH = {
    size         = "XSMALL"
    auto_suspend = 60
    auto_resume  = true
  }
  REPORTER_WH = {
    size         = "XSMALL"
    auto_suspend = 60
    auto_resume  = true
  }
  CI_WH = {
    size         = "XSMALL"
    auto_suspend = 60
    auto_resume  = true
  }
  MARKETING_WH = {
    size         = "XSMALL"
    auto_suspend = 60
    auto_resume  = true
  }
  DATA_PLATFORM_WH = {
    size         = "MEDIUM"
    auto_suspend = 120
    auto_resume  = true
  }
  FINANCE_WH = {
    size         = "XSMALL"
    auto_suspend = 60
    auto_resume  = true
  }
}
