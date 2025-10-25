resource "aws_security_group" "eventCollector_sg" {
  name        = "${var.environment}-${var.service}-ec-fargate-sg"
  vpc_id      = data.terraform_remote_state.evt_infra.outputs.vpc_id
  description = "Allow http traffic"

  lifecycle {
    create_before_destroy = true
  }

  ingress {
    from_port       = var.app_port # HTTP
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb-sg.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    ApplicationName   = "${var.environment}-${var.service}-ec-fargate-sg"
    Environment       = var.info_sec_environment
    ResourceOwner     = var.resource_owner
    DataClassification = var.data_classification
    DataTaxonomy      = var.data_taxonomy
    CiscoMailAlias    = var.cisco_mail_alias
    Project           = var.environment
  }
}

locals {
  timestampTag = timestamp()
  privateSubnets = split(
    ",",
    data.terraform_remote_state.evt_infra.outputs.private_subnet_ids,
  )
  goMemLimit    = floor(var.ec_task_memory * var.gomemlimit_percentage / 100)
  goMemLimitMiB = format("%dMiB", local.goMemLimit)
}

data "template_file" "ec_container_defn" {
  template = file("./eventCollectorContainer.tpl")

  vars = {
    ec_image                         = var.ec_image
    firehose_stream_name             = data.terraform_remote_state.evt_ingest.outputs.ingest_stream
    streamRegion                     = var.streamRegion
    eventingTestConnStream           = var.eventingTestConnStream
    cdoTestConnEventStream           = var.cdoTestConnEventStream
    connEventStreamRoleARN           = var.connEventStreamRoleARN
    talosRoleARN                     = var.talosRoleARN
    talosExternalID                  = var.talosExternalID
    talosRegion                      = var.talosRegion
    talosStreamName                  = var.talosStreamName
    ztnaRoleARN                      = var.ztnaRoleARN
    ztnaExternalID                   = var.ztnaExternalID
    ztnaRegion                       = var.ztnaRegion
    ztnaStreamName                   = var.ztnaStreamName
    streamPrefix                     = var.streamPrefix
    connEventStreamRoleExternalID    = var.connEventStreamRoleExternalID
    redis_addr                       = data.terraform_remote_state.evt_redis.outputs.endpoint
    maxMsgsPerSecond                 = var.maxMsgsPerSecond
    api_key                          = local.datadog_keys.api_key
    datadog_enabled                  = var.datadog_enabled
    datadog_api_url                  = var.datadog_api_url
    splunk_enabled                   = var.splunk_enabled
    splunk_url                       = var.splunk_url
    sqs_url                          = var.sqs_url
    sqsReportingEnabled              = var.sqsReportingEnabled
    metric_interval                  = var.metric_interval
    bucket                           = "${var.account}-state"
    environment                      = var.environment
    region                           = var.region
    service                          = var.service
    cn                               = var.cn
    account                          = var.account
    vault_service                    = var.vault_service
    vault_address                    = "https://${data.terraform_remote_state.evt_infra.outputs.sse_fqdn}"
    approle_id                       = ""
    secret_id                        = ""
    app_key                          = local.datadog_keys.app_key
    log_group                        = data.terraform_remote_state.evt_infra.outputs.eventing_log_group
    testTenantId                     = var.testTenantId
    redis_alb_domain                 = var.redis_alb_domain
    fips_enabled                     = var.fips_enabled
    cpu_max_threshold                = var.cpu_max_threshold
    memory_max_threshold             = var.memory_max_threshold
    evtSvcTokenName                  = data.terraform_remote_state.evt_svcToken.outputs.evtSvcToken_name
    generic_field_handling           = var.generic_field_handling
    generic_field_handling_report_error = var.generic_field_handling_report_error
    ec_task_memory                   = var.ec_task_memory
    ec_task_cpu                      = var.ec_task_cpu
    s3ReportingEnabled               = var.s3ReportingEnabled
    custom_error_debugger            = var.custom_error_debugger
    cpu_percent_for_connection_rejection   = var.cpu_percent_for_connection_rejection
    memory_percent_for_connection_rejection = var.memory_percent_for_connection_rejection
    cpu_percent_for_connection_deletion    = var.cpu_percent_for_connection_deletion
    memory_percent_for_connection_deletion = var.memory_percent_for_connection_deletion
    resource_monitor_frequency_secs        = var.resource_monitor_frequency_secs
    connection_rejection            = var.connection_rejection
    connection_deletion             = var.connection_deletion
    containerInsightsEnabled        = var.containerInsightsEnabled
    gomemlimit                      = local.goMemLimitMiB
  }
}

resource "aws_ecs_task_definition" "event-collector" {
  family                   = "event-collector"
  task_role_arn            = aws_iam_role.ec_ecs_instance_role.arn
  execution_role_arn       = aws_iam_role.ec_ecs_instance_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = var.ec_task_memory
  cpu                      = var.ec_task_cpu
  container_definitions    = data.template_file.ec_container_defn.rendered

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Project = var.environment
  }
}

resource "aws_ecs_service" "event-collector-service" {
  name            = "${var.ecs_service_name}-${aws_ecs_task_definition.event-collector.revision}"
  cluster         = data.terraform_remote_state.evt_infra.outputs.ecs_cluster
  task_definition = aws_ecs_task_definition.event-collector.arn
  desired_count   = var.desired_count
  propagate_tags  = "TASK_DEFINITION"
  launch_type     = "FARGATE"

  lifecycle {
    create_before_destroy = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.alb_target_group.arn
    container_name   = "ecContainer"
    container_port   = var.app_port
  }

  depends_on = [aws_lb_listener.alb_listener]

  network_configuration {
    security_groups = [aws_security_group.eventCollector_sg.id]
    subnets         = [local.privateSubnets[0], local.privateSubnets[1]]
  }

  tags = {
    Project = var.environment
  }
}

resource "aws_s3_bucket" "ec-debug" {
  bucket = "ec-${var.environment}-debug"

  tags = {
    ApplicationName   = "ec-${var.environment}-debug"
    Environment       = var.info_sec_environment
    ResourceOwner     = var.resource_owner
    DataClassification = var.data_classification
    DataTaxonomy      = var.data_taxonomy
    CiscoMailAlias    = var.cisco_mail_alias
    Project           = var.environment
  }
}

resource "aws_s3_bucket_ownership_controls" "ec-debug-ownership" {
  bucket = aws_s3_bucket.ec-debug.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "ec-debug_acl" {
  bucket     = aws_s3_bucket.ec-debug.bucket
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.ec-debug-ownership]
}

resource "aws_s3_bucket_lifecycle_configuration" "ec-debug_lc" {
  bucket = aws_s3_bucket.ec-debug.bucket

  rule {
    status = "Enabled"
    id     = "ExpireObjectsAt7Days"

    expiration {
      days = "7"
    }
  }
}

output "ec-service-name" {
  value = aws_ecs_service.event-collector-service.name
}

resource "aws_s3_bucket" "ec-config" {
  bucket = "${var.environment}-${var.service}-ec-config"
}

resource "aws_s3_bucket_ownership_controls" "ec-config-ownership" {
  bucket = aws_s3_bucket.ec-config.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "ec-config-acl" {
  bucket     = aws_s3_bucket.ec-config.bucket
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.ec-config-ownership]
}

resource "aws_s3_bucket_object" "ec-config-catelog" {
  bucket = aws_s3_bucket.ec-config.bucket
  key    = "ftdEventCatalog.json"
  source = "../../conf/ftdEventCatalog.json"
  etag   = filemd5("../../conf/ftdEventCatalog.json")
}

resource "aws_s3_bucket_object" "ec-config-syslog" {
  bucket = aws_s3_bucket.ec-config.bucket
  key    = "ftdSyslogEventConfig.json"
  source = "../../conf/ftdSyslogEventConfig.json"
  etag   = filemd5("../../conf/ftdSyslogEventConfig.json")
}

resource "aws_s3_bucket" "ec-metrics" {
  bucket = "${var.environment}-ec-metrics"
}

resource "aws_s3_bucket_ownership_controls" "ec-metrics-ownership" {
  bucket = aws_s3_bucket.ec-metrics.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "ec-metrics-acl" {
  bucket     = aws_s3_bucket.ec-metrics.bucket
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.ec-metrics-ownership]
}

resource "aws_s3_bucket_lifecycle_configuration" "ec-metrics_lc" {
  bucket = aws_s3_bucket.ec-metrics.bucket

  rule {
    status = "Enabled"
    id     = "ExpireObjectsAt7Days"

    expiration {
      days = "7"
    }
  }
}
