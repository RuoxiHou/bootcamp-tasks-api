resource "helm_release" "kube_prometheus_stack" {
  name       = "monitoring"
  namespace  = var.namespace
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "88.3.0"

  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true

  values = [
    templatefile("${path.module}/values/prometheus-values.yaml.tftpl", {
      tasks_api_namespace    = var.tasks_api_namespace
      tasks_api_service_name = var.tasks_api_service_name
    })
  ]

  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
    type  = "string"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = var.prometheus_storage_size
  }

  depends_on = [
    kubernetes_namespace.monitoring
  ]
}