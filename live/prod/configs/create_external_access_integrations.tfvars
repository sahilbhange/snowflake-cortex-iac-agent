enable_external_access_integrations = true

external_access_integrations = {
  PYPI_ACCESS_INTEGRATION = {
    enabled                  = true
    allowed_network_rules    = ["ADMIN_DB.GOVERNANCE.PYPI_NETWORK_RULE"]
    allowed_api_integrations = []
    comment                  = "Allows PyPI egress via network rule"
  }

  GIT_ACCESS_INTEGRATION = {
    enabled                  = true
    allowed_network_rules    = ["ADMIN_DB.GOVERNANCE.PYPI_NETWORK_RULE"]
    allowed_api_integrations = []
    comment                  = "Allows GitHub egress via network rule"
  }
}
