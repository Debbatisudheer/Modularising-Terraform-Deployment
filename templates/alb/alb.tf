resource "aws_lb" "{{deployments}}-alb" {
  name               = "${var.environment}-${var.service}-{{deployments}}-alb"
  internal           = var.lb_internal
  load_balancer_type = "application"
  ip_address_type    = "dualstack"
  idle_timeout       = var.idle_timeout

  security_groups = [aws_security_group.{{deployments}}-alb-sg.id]

  subnets = split(
    ",",
    data.terraform_remote_state.evt_infra.outputs.public_subnet_ids,
  )

  # enable_deletion_protection = true

  access_logs {
    bucket  = aws_s3_bucket.{{deployments}}-alb_logs.bucket
    prefix  = "${var.service}-lb-logs"
    enabled = true
  }

  tags = {
    ApplicationName   = "${var.environment}-${var.service}-{{deployments}}alb"
    Service           = var.service
    Environment       = var.info_sec_environment
    ResourceOwner     = var.resource_owner
    DataClassification = var.data_classification
    DataTaxonomy      = var.data_taxonomy
    CiscoMailAlias    = var.cisco_mail_alias
    Project           = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_alb_target_group" "{{deployments}}-alb_target_group" {
  name     = "${var.environment}-${var.target_group_name}"
  port     = var.app_port
  protocol = var.app_protocol
  vpc_id   = data.terraform_remote_state.evt_infra.outputs.vpc_id
  target_type = var.target_type

  tags = {
    ApplicationName   = "${var.environment}-${var.target_group_name}-{{deployments}}-alb_target_group"
    Environment       = var.info_sec_environment
    ResourceOwner     = var.resource_owner
    DataClassification = var.data_classification
    DataTaxonomy      = var.data_taxonomy
    CiscoMailAlias    = var.cisco_mail_alias
    Project           = var.environment
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 1800
    enabled         = var.target_group_sticky
  }

  health_check {
    healthy_threshold   = var.lb_monitor_max_retries_healthy
    unhealthy_threshold = var.lb_monitor_max_retries_unhealthy
    timeout             = var.lb_monitor_timeout
    interval            = var.lb_monitor_interval
    path                = var.lb_monitor_target
    port                = var.app_port
    protocol            = var.lb_protocol
  }
}

resource "aws_lb_listener" "{{deployments}}-alb_listener" {
  load_balancer_arn = aws_lb.{{deployments}}-alb.arn
  port              = var.lb_port
  protocol          = var.lb_protocol
  certificate_arn   = data.aws_acm_certificate.alb_acm_cert.arn
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "403"
    }
  }
}

resource "aws_lb_listener_rule" "{{deployments}}-ingest_rule" {
  listener_arn = aws_lb_listener.{{deployments}}-alb_listener.arn

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.{{deployments}}-alb_target_group.arn
  }

  condition {
    path_pattern {
      values = [var.ingest_path]
    }
  }
}

resource "aws_lb_listener_rule" "{{deployments}}-health_rule" {
  listener_arn = aws_lb_listener.{{deployments}}-alb_listener.arn

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.{{deployments}}-alb_target_group.arn
  }

  condition {
    path_pattern {
      values = [var.health_path]
    }
  }
}

resource "aws_security_group" "{{deployments}}-alb-sg" {
  name        = "${var.environment}-${var.service}-main-alb-sg"
  description = "ALB SG"
  vpc_id      = data.terraform_remote_state.evt_infra.outputs.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    ApplicationName   = "${var.environment}-${var.service}-main-{{deployments}}-alb-sg"
    Environment       = var.info_sec_environment
    ResourceOwner     = var.resource_owner
    DataClassification = var.data_classification
    DataTaxonomy      = var.data_taxonomy
    CiscoMailAlias    = var.cisco_mail_alias
    Project           = var.environment
  }

  ingress {
    from_port   = var.lb_port # HTTPS
    to_port     = var.lb_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port        = var.lb_port # HTTPS
    to_port          = var.lb_port
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = var.app_port # HTTPS
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_s3_bucket" "{{deployments}}-alb_logs" {
  bucket = "${var.environment}-${var.service}-alb-logs"

  tags = {
    ApplicationName   = "${var.environment}-${var.service}-{{deployments}}-alb-logs"
    Environment       = var.info_sec_environment
    ResourceOwner     = var.resource_owner
    DataClassification = var.data_classification
    DataTaxonomy      = var.data_taxonomy
    CiscoMailAlias    = var.cisco_mail_alias
    Project           = var.environment
  }
}

resource "aws_s3_bucket_policy" "{{deployments}}-alb_bucket_policy" {
  bucket = aws_s3_bucket.{{deployments}}-alb_logs.id
  policy = data.aws_iam_policy_document.{{deployments}}-alb_policy_configuration.json
}

data "aws_iam_policy_document" "{{deployments}}-alb_policy_configuration" {
  version = "2012-10-17"

  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "arn:aws:s3:::${var.environment}-${var.service}-alb-logs/${var.service}-lb-logs/*"
    ]

    principals {
      type        = "AWS"
      identifiers = ["${data.aws_elb_service_account.main.arn}"]
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "{{deployments}}-alb_logs" {
  bucket = aws_s3_bucket.{{deployments}}-alb_logs.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_acl" "{{deployments}}-alb_logs_acl" {
  bucket = aws_s3_bucket.{{deployments}}-alb_logs.bucket
  acl    = "private"

  depends_on = [aws_s3_bucket_ownership_controls.{{deployments}}-alb_logs]
}

resource "aws_s3_bucket_lifecycle_configuration" "{{deployments}}-alb_logs_lc" {
  bucket = aws_s3_bucket.{{deployments}}-alb_logs.bucket

  rule {
    status = "Enabled"
    id     = "ExpireObjectsAt181Days"

    expiration {
      days = "181"
    }
  }
}
