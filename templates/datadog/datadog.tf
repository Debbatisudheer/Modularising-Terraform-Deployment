resource "datadog_monitor" "{{deployments}}-eventing-event-collector-cpu-utilization" {
  name    = "${var.environment}:{{deployments}}:EventCollector_Cpu_Utilization_Alarm"
  type    = "metric alert"
  message = "Monitors the average percentage of CPU resources used across all Event Collector tasks in the cluster. In case of alarm notify: @${var.ddNotify}"

  query = "avg(last_5m):avg:aws.ecs.cpuutilization{clustername:${var.environment},servicename:${var.ecs_service_name}-${aws_ecs_task_definition.event-collector.revision}}>=${var.cpu_max_threshold}"

  notify_no_data   = false
  renotify_interval = 60
  notify_audit     = false
  timeout_h        = 1

  tags = [
    var.environment,
    var.service,
    var.owner
  ]

  count = "${var.datadog_enabled == "true" ? 1 : 0}"
}
