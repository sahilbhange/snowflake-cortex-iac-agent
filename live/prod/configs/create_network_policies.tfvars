enable_network_policies = true

network_policies = {
  ACCOUNT_NETWORK_POLICY = {
    allowed_ip_list = [
      "0.0.0.0/0"  # PLACEHOLDER — replace with actual office/VPN CIDRs before applying
    ]
    blocked_ip_list = []
    comment         = "Account-level network policy — controls inbound access"
  }
}
