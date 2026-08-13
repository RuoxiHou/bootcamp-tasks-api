resource "kubernetes_namespace" "keda" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "keda" {
  name       = "keda"
  namespace  = var.namespace
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = var.chart_version

  create_namespace = false
  atomic           = true
  cleanup_on_fail  = true

  set {
    name  = "operator.replicaCount"
    value = tostring(var.operator_replica_count)
  }

  depends_on = [
    kubernetes_namespace.keda
  ]
}