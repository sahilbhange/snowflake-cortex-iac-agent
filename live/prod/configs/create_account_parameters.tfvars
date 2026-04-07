enable_account_parameters = true

account_parameters = {
  # -- Session / Query Guardrails
  STATEMENT_TIMEOUT_IN_SECONDS        = "3600"  # 1 h  kill long running queries
  STATEMENT_QUEUED_TIMEOUT_IN_SECONDS = "600"   # 10 min  fail if queued too long
  CLIENT_SESSION_KEEP_ALIVE           = "false" # don't hold idle sessions open

  #  Timezone & Locale 
  TIMEZONE = "ET" # consistent timestamps across all sessions

  #  Data Retention & Recovery 
  DATA_RETENTION_TIME_IN_DAYS = "30" # 30-day Time Travel

  #  Metadata & Auditing 
  # ENABLE_UNREDACTED_QUERY_SYNTAX_ERROR = "true"  # surface full SQL in error logs
  USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = "XSMALL" # default serverless task size

  #  Network & Security 
  #PERIODIC_DATA_REKEYING = "false"  # disable automatic rekeying (Enterprise only)
  #NETWORK_POLICY          = ""      

  #  Cost Control 
  USE_CACHED_RESULT = "true" # reuse results when query + context match
}
