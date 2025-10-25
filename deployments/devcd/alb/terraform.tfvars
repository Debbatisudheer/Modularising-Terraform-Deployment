environment                         = "dev" 
service                             = "ecstaskchecker"
info_sec_environment                = ""
albDomain                           = ""
cn                                   = "dev-event-collector.sse.com"
deployment                          = "ise"

account                             = "123456789012"

account                             = "123456789012"
environment                         = "dev"
service                             = "ecstaskchecker"
region                              = "us-east-1" # This is added
albDomain                           = ""
cn                                   = "dev-event-collector.sse.com"
deployment                          = "ise"  # You can change this dynamically or keep it static as per your needs.
info_sec_environment                = ""

lb_internal                         = "false"  # If you want to override the default, otherwise omit it.
app_port                            = "9443"  # Omit if you want to use the default.
app_protocol                        = "HTTPS"  # Omit if you want to use the default.
lb_port                             = "443"  # Omit if you want to use the default.
lb_protocol                         = "HTTPS"  # Omit if you want to use the default.
lb_monitor_target                   = "/health"  # Omit if you want to use the default.
lb_monitor_timeout                  = "5"  # Omit if you want to use the default.
lb_monitor_interval                 = "60"  # Omit if you want to use the default.
lb_monitor_max_retries_healthy      = "2"  # Omit if you want to use the default.
lb_monitor_max_retries_unhealthy    = "2"  # Omit if you want to use the default.
idle_timeout                        = "4000"  # Omit if you want to use the default.
ingest_path                         = "/ingest"  # Omit if you want to use the default.
health_path                        = "/health"  # Omit if you want to use the default.
target_group_name                   = "event-collector"  # Omit if you want to use the default.
target_group_sticky                 = "false"  # Omit if you want to use the default.
target_type                         = "ip"  # Omit if you want to use the default.
cisco_mail_alias                    = "sse-ops@cisco.com"  # Omit if you want to use the default.
data_classification                 = "Cisco Confidential"  # Omit if you want to use the default.
data_taxonomy                       = "Administrative Data"  # Omit if you want to use the default.
resource_owner                      = "SBG-SSE"  # Omit if you want to use the default.