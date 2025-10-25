resource "signalfx_detector" "{{deployments}}-eventing-event-collector-cpu-utilization" {
  name        = "${var.environment}:{{deployments}}:EventCollector_Cpu_Utilization_Alarm"
  description = "Monitors the average percentage of CPU resources used across all Event Collector tasks in the cluster."

  program_text = <<-EOF
    signal = data('CPUUtilization',
                  filter=filter('ClusterName', '${var.environment}') 
                  and filter('ServiceName', '${var.ecs_service_name}-${aws_ecs_task_definition.event-collector.revision}') 
                  and filter('stat', 'mean')
              ).mean(over='5m').publish('signal')

    detect(when(signal >= ${var.cpu_max_threshold}, '5m')).publish('Processing old messages 5m')
  EOF

  max_delay = 300
  teams     = [var.splunkteamsID]

  rule {
    description   = "Mean >= ${var.cpu_max_threshold} for 5m"
    severity      = "Critical"
    detect_label  = "Processing old messages 5m"
    notifications = var.splunkNotificationWithoutPagerDuty
  }

  tags  = [var.environment, var.service, var.owner]
  count = "${var.splunk_enabled == "true" ? 1 : 0}"
}
