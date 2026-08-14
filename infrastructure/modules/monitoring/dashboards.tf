resource "kubernetes_config_map_v1" "grafana_dashboard_tasks_api" {
  metadata {
    name      = "monitoring-grafana-dashboard-tasks-api"
    namespace = var.namespace
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = "Tasks API"
    }
  }

  data = {
    "tasks-api-observability.json" = templatefile("${path.module}/values/dashboards/tasks-api-observability.json.tftpl", {
      prometheus_uid = "prometheus"
      loki_uid       = "loki"
      grafana_path   = "/metrics/grafana"
      namespace      = var.tasks_api_namespace
      service_name   = var.tasks_api_service_name
    })
  }

  depends_on = [
    kubernetes_namespace.monitoring
  ]
}

resource "kubernetes_config_map_v1" "grafana_dashboard_tasks_api_business" {
  metadata {
    name      = "monitoring-grafana-dashboard-tasks-api-business"
    namespace = var.namespace
    labels = {
      grafana_dashboard = "1"
    }
    annotations = {
      grafana_folder = "Tasks API Business"
    }
  }

  data = {
    "tasks-api-business-kpis.json" = templatefile("${path.module}/values/dashboards/tasks-api-business-kpis.json.tftpl", {
      prometheus_uid = "prometheus"
      loki_uid       = "loki"
      namespace      = var.tasks_api_namespace
      service_name   = var.tasks_api_service_name
    })
  }

  depends_on = [
    kubernetes_namespace.monitoring
  ]
}