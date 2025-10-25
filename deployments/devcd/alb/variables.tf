
variable "environment" {
}

variable "service" {
}

variable "lb_internal" {
  default = "false"
}

variable "idle_timeout" {
  default = "4000"
}

variable "info_sec_environment" {
}

variable "resource_owner" {
  default = "SBG-SSE"
}

variable "data_classification" {
  default = "Cisco Confidential"
}

variable "data_taxonomy" {
  default = "Administrative Data"
}

variable "cisco_mail_alias" {
  default = "sse-ops@cisco.com"
}

variable "app_port" {
  default = "9443"
}

variable "app_protocol" {
  default = "HTTPS"
}

variable "lb_port" {
  default = "443"
}

variable "lb_protocol" {
  default = "HTTPS"
}

variable "lb_monitor_target" {
  default = "/health"
}

variable "lb_monitor_timeout" {
  default = "5"
}

variable "lb_monitor_interval" {
  default = "60"
}

variable "lb_monitor_max_retries_healthy" {
  default = "2"
}

variable "lb_monitor_max_retries_unhealthy" {
  default = "2"
}

variable "target_group_name" {
  default = "event-collector"
}

variable "target_group_sticky" {
  default = "false"
}

variable "target_type" {
  default = "ip"
}

variable "ingest_path" {
  default = "/ingest"
}

variable "health_path" {
  default = "/health"
}

variable "albDomain" {
}

terraform {
  backend "s3" {
    bucket  = "{{ account }}-state"
    key     = "{{ environment }}/{{ service }}/$deployment/terraform.state"
    region  = "{{ aws_region }}"
    encrypt = 1
  }
}
