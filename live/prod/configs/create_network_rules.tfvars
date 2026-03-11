enable_network_rules = true

network_rules = {
  PYPI_NETWORK_RULE = {
    database = "ADMIN_DB"
    schema   = "GOVERNANCE"
    type     = "HOST_PORT"
    mode     = "EGRESS"
    value_list = [
      "pypi.org",
      "pypi.python.org",
      "pythonhosted.org",
      "files.pythonhosted.org",
      "github.com",
      "*.github.com",
      "*.githubusercontent.com"
    ]
    comment = "PyPI and GitHub egress"
  }
}
