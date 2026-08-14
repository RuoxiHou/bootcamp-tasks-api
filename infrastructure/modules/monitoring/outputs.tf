output "namespace" {
  value = kubernetes_namespace.monitoring.metadata[0].name
}

output "prometheus_service" {
  value = "monitoring-kube-prometheus-prometheus"
}

output "grafana_service" {
  value = "monitoring-grafana"
}

output "loki_gateway_service" {
  value = "loki-gateway"
}

output "alloy_release" {
  value = helm_release.alloy.name
}