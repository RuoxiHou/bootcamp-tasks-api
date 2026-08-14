resource "helm_release" "loki" {
  name       = "loki"
  namespace  = var.namespace
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = "7.3.0"

  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true

  values = [
    file("${path.module}/values/loki-values.yaml")
  ]

  set {
    name  = "deploymentMode"
    value = "SingleBinary"
  }

  set {
    name  = "singleBinary.replicas"
    value = "1"
  }

  set {
    name  = "singleBinary.persistence.size"
    value = var.loki_storage_size
  }

  depends_on = [
    kubernetes_namespace.monitoring
  ]
}

resource "helm_release" "alloy" {
  name       = "alloy"
  namespace  = var.namespace
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  version    = "1.11.1"

  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true

  values = [
    templatefile("${path.module}/values/alloy-values.yaml.tftpl", {
      cluster_name  = var.cluster_name
      loki_push_url = "http://loki-gateway.${var.namespace}.svc.cluster.local/loki/api/v1/push"
    })
  ]

  depends_on = [
    helm_release.loki
  ]
}
