# -----------------------------
# WAFv2 Rule Group
# -----------------------------
resource "aws_wafv2_rule_group" "{{deployments}}-ec_wafv2_rule_group" {
  name     = "${var.environment}-${var.service}-{{deployments}}-ec-wafv2-rulegroup"
  scope    = "REGIONAL"
  capacity = 8

  # Geo Block
  rule {
    name     = "${var.environment}-${var.service}-{{deployments}}-ec-geo-block-rule"
    priority = 1
    action { block {} }

    statement {
      geo_match_statement {
        country_codes = split(",", var.geo_block_country_codes)
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "{{deployments}}-ec-wafv2-rule-geo-block"
      sampled_requests_enabled   = false
    }
  }

  # IPv4
  rule {
    name     = "${var.environment}-${var.service}-{{deployments}}-ec-rule-group-ipv4"
    priority = 2
    action { block {} }

    statement {
      ip_set_reference_statement {
        arn = data.aws_wafv2_ip_set.{{deployments}}-wafv2-ip-set-v4.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}-${var.service}-{{deployments}}-ec-rule-ipv4"
      sampled_requests_enabled   = false
    }
  }

  # IPv4-1
  rule {
    name     = "${var.environment}-${var.service}-{{deployments}}-ec-rule-group-ipv4-1"
    priority = 3
    action { block {} }

    statement {
      ip_set_reference_statement {
        arn = data.aws_wafv2_ip_set.{{deployments}}-wafv2-ip-set-v4-1.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}-${var.service}-{{deployments}}-ec-rule-ipv4"
      sampled_requests_enabled   = false
    }
  }

  # IPv6
  rule {
    name     = "${var.environment}-${var.service}-{{deployments}}-ec-rule-group-ipv6"
    priority = 4
    action { block {} }

    statement {
      ip_set_reference_statement {
        arn = data.aws_wafv2_ip_set.{{deployments}}-wafv2-ip-set-v6.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}-${var.service}-{{deployments}}-ec-rule-ipv6"
      sampled_requests_enabled   = false
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.environment}-${var.service}-{{deployments}}-ec-wafv2-rulegroup"
    sampled_requests_enabled   = false
  }
}

# -----------------------------
# WAFv2 Web ACL
# -----------------------------
resource "aws_wafv2_web_acl" "{{deployments}}-ec-wafv2-webacl" {
  name  = "${var.environment}-${var.service}-{{deployments}}-ec-wafv2-webacl"
  scope = "REGIONAL"

  depends_on = [
    aws_wafv2_rule_group.{{deployments}}-ec_wafv2_rule_group
  ]

  default_action { allow {} }

  # Attach Rule Group
  rule {
    name     = "${var.environment}-${var.service}-{{deployments}}-ec-wafv2-block-geo-ipset-rule-group"
    priority = 1

    override_action { none {} }

    statement {
      rule_group_reference_statement {
        arn = aws_wafv2_rule_group.{{deployments}}-ec_wafv2_rule_group.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}-${var.service}-{{deployments}}-ec-wafv2-block-geo-ipset-rule"
      sampled_requests_enabled   = false
    }
  }

  # Rate Limit Rule
  rule {
    name     = "${var.environment}-${var.service}-{{deployments}}-ec-wafv2-web-acl-ip-rate-limit-rule"
    priority = 2
    action { block {} }

    statement {
      rate_based_statement {
        limit              = var.per_ip_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.environment}-${var.service}-{{deployments}}-ec-wafv2-webacl-ip-rate-limit-rule"
      sampled_requests_enabled   = false
    }
  }

  tags = {
    Environment = var.environment
    Account     = var.account
    Owner       = var.owner
    Service     = var.service
    Project     = var.environment
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "{{deployments}}-wafv2-ec-per-ec-wafv2-webacl"
    sampled_requests_enabled   = false
  }
}

# -----------------------------
# Web ACL Association with ALB
# -----------------------------
resource "aws_wafv2_web_acl_association" "{{deployments}}-ec_wafv2_acl_association" {
  resource_arn = aws_lb.{{deployments}}-alb.arn
  web_acl_arn  = aws_wafv2_web_acl.{{deployments}}-ec-wafv2-webacl.arn

  depends_on = [
    aws_wafv2_web_acl.{{deployments}}-ec-wafv2-webacl
  ]
}
