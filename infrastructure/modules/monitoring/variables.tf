variable "namespace" {
  description = "Kubernetes namespace for the monitoring stack"
  type        = string
  default     = "monitoring"
}

variable "tasks_api_namespace" {
  description = "Namespace where tasks-api is deployed"
  type        = string
  default     = "default"
}

variable "tasks_api_service_name" {
  description = "Kubernetes Service name for tasks-api"
  type        = string
  default     = "tasks-api"
}

variable "cluster_name" {
  description = "Cluster label attached to collected log streams"
  type        = string
}

variable "prometheus_storage_size" {
  description = "Persistent storage size for Prometheus"
  type        = string
  default     = "10Gi"
}

variable "loki_storage_size" {
  description = "Persistent storage size for Loki"
  type        = string
  default     = "20Gi"
}

variable "grafana_admin_password" {
  description = "Grafana administrator password"
  type        = string
  sensitive   = true
}

variable "grafana_public_url" {
  description = "Public URL where Grafana is served, including its subpath"
  type        = string
}

variable "alert_email_address" {
  description = "Email address that should receive Grafana/Alertmanager notifications."
  type        = string
}

variable "alert_smtp_smarthost" {
  description = "SMTP smarthost in host:port format for Alertmanager email delivery."
  type        = string
  default     = ""
}

variable "alert_email_from" {
  description = "From address used for Alertmanager email notifications."
  type        = string
  default     = ""
}

variable "alert_smtp_auth_username" {
  description = "SMTP username used by Alertmanager for email delivery."
  type        = string
  default     = ""
  sensitive   = true
}

variable "alert_smtp_auth_password" {
  description = "SMTP password used by Alertmanager for email delivery."
  type        = string
  default     = ""
  sensitive   = true
}