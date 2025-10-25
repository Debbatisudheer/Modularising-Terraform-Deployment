
data "aws_wafv2_ip_set" "wafv2-ip-set-v4" {
  name  = "${var.environment}-${var.service}-ipset-v4"
  scope = "REGIONAL"
}

data "aws_wafv2_ip_set" "wafv2-ip-set-v4-1" {
  name  = "${var.environment}-${var.service}-ipset-v4-1"
  scope = "REGIONAL"
}

data "aws_wafv2_ip_set" "wafv2-ip-set-v6" {
  name  = "${var.environment}-${var.service}-ipset-v6"
  scope = "REGIONAL"
}

