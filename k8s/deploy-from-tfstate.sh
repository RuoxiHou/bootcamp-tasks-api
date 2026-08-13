#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="$ROOT_DIR/infrastructure"
K8S_BASE_DIR="$ROOT_DIR/k8s/base"
CERT_MANAGER_VERSION="v1.16.5"
K8S_NAMESPACE="${K8S_NAMESPACE:-default}"
DEPLOY_EDGE_RESOURCES="${DEPLOY_EDGE_RESOURCES:-true}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd terraform
require_cmd kubectl
require_cmd envsubst
require_cmd helm

# Pull AKS context from Terraform outputs when Azure CLI is available.
if command -v az >/dev/null 2>&1; then
  AKS_RG="$(terraform -chdir="$INFRA_DIR" output -raw resource_group_name)"
  AKS_NAME="$(terraform -chdir="$INFRA_DIR" output -raw aks_name)"
  az aks get-credentials \
    --resource-group "$AKS_RG" \
    --name "$AKS_NAME" \
    --overwrite-existing >/dev/null
else
  echo "Warning: 'az' CLI not found. Using current kubectl context." >&2
fi

# Read deployment values from Terraform state outputs.
KEY_VAULT_NAME="$(terraform -chdir="$INFRA_DIR" output -raw key_vault_name)"
WORKLOAD_IDENTITY_CLIENT_ID="$(terraform -chdir="$INFRA_DIR" output -raw workload_identity_client_id)"
AZURE_TENANT_ID="$(terraform -chdir="$INFRA_DIR" output -raw tenant_id)"
AZURE_SUBSCRIPTION_ID="$(terraform -chdir="$INFRA_DIR" output -raw subscription_id)"
EXTERNALDNS_CLIENT_ID="$(terraform -chdir="$INFRA_DIR" output -raw externaldns_client_id)"
AZURE_DNS_RESOURCE_GROUP="$(terraform -chdir="$INFRA_DIR" output -raw resource_group_name)"
DNS_ZONE_NAME="$(terraform -chdir="$INFRA_DIR" output -raw dns_zone_name)"
ACR_LOGIN_SERVER="$(terraform -chdir="$INFRA_DIR" output -raw acr_login_server)"
TASKS_API_HOSTNAME="api.${DNS_ZONE_NAME}"
TASKS_API_IMAGE="${TASKS_API_IMAGE:-${ACR_LOGIN_SERVER}/tasks-api:latest}"
GRAFANA_DASHBOARDS_URL="https://${TASKS_API_HOSTNAME}/metrics/grafana/d/tasks-api-observability/tasks-api-observability"

export KEY_VAULT_NAME
export WORKLOAD_IDENTITY_CLIENT_ID
export AZURE_TENANT_ID
export AZURE_SUBSCRIPTION_ID
export EXTERNALDNS_CLIENT_ID
export AZURE_DNS_RESOURCE_GROUP
export DNS_ZONE_NAME
export TASKS_API_HOSTNAME
export TASKS_API_IMAGE
export GRAFANA_DASHBOARDS_URL
export K8S_NAMESPACE

if [[ "$DEPLOY_EDGE_RESOURCES" == "true" ]]; then
  if ! kubectl get gatewayclass approuting-istio >/dev/null 2>&1; then
    echo "GatewayClass 'approuting-istio' not found. Enable AKS application routing first." >&2
    exit 1
  fi

  if [ -z "${CERT_MANAGER_EMAIL:-}" ]; then
    echo "ERROR: CERT_MANAGER_EMAIL must be set for cert-manager ClusterIssuer" >&2
    exit 1
  fi

  export CERT_MANAGER_EMAIL
fi

kubectl get namespace "$K8S_NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$K8S_NAMESPACE" >/dev/null

# Apply resources in dependency order.
envsubst < "$K8S_BASE_DIR/tasks-api-serviceaccount.yaml" | kubectl apply -f -
envsubst < "$K8S_BASE_DIR/tasks-api-secret-provider.yaml" | kubectl apply -f -

envsubst < "$K8S_BASE_DIR/tasks-api-service.yaml" | kubectl apply -f -
envsubst < "$K8S_BASE_DIR/tasks-api-pdb.yaml" | kubectl apply -f -
envsubst < "$K8S_BASE_DIR/tasks-api-deployment.yaml" | kubectl apply -f -

if kubectl get crd scaledobjects.keda.sh >/dev/null 2>&1; then
  envsubst < "$K8S_BASE_DIR/tasks-api-scaledobject.yaml" | kubectl apply -f -
else
  echo "Warning: KEDA CRD 'scaledobjects.keda.sh' not found. Apply infrastructure autoscaling changes first." >&2
fi

if kubectl get crd nodepools.karpenter.sh >/dev/null 2>&1 && kubectl get crd aksnodeclasses.karpenter.azure.com >/dev/null 2>&1; then
  kubectl apply -f "$K8S_BASE_DIR/nap-default-nodepool.yaml"
else
  echo "Warning: AKS NAP/Karpenter CRDs not found. Enable AKS node auto-provisioning before applying NodePool policy." >&2
fi

if [[ "$DEPLOY_EDGE_RESOURCES" == "true" ]]; then
  kubectl apply -f "$K8S_BASE_DIR/cert-manager-namespace.yaml"

  helm repo add jetstack https://charts.jetstack.io --force-update
  helm repo update jetstack

  helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --version "$CERT_MANAGER_VERSION" \
    --values "$K8S_BASE_DIR/../helm/cert-manager/values.yaml" \
    --set-string "serviceAccount.annotations.azure\.workload\.identity/client-id=${EXTERNALDNS_CLIENT_ID}" \
    --server-side=false \
    --wait \
    --timeout 5m

  kubectl rollout status deployment/cert-manager -n cert-manager --timeout=180s
  kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=180s
  kubectl rollout status deployment/cert-manager-cainjector -n cert-manager --timeout=180s

  envsubst < "$K8S_BASE_DIR/cert-manager-issuer.yaml" | kubectl apply -f -
  envsubst < "$K8S_BASE_DIR/cert-manager-certificate.yaml" | kubectl apply -f -

  kubectl apply -f "$K8S_BASE_DIR/tasks-api-gateway.yaml"
  kubectl get namespace monitoring >/dev/null 2>&1 || {
    echo "Monitoring namespace not found. Apply Terraform monitoring resources first." >&2
    exit 1
  }
  envsubst < "$K8S_BASE_DIR/tasks-api-httproute.yaml" | kubectl apply -f -

  kubectl apply -f "$K8S_BASE_DIR/external-dns-rbac.yaml"
  envsubst < "$K8S_BASE_DIR/external-dns-serviceaccount.yaml" | kubectl apply -f -
  envsubst < "$K8S_BASE_DIR/external-dns-azure-config.yaml" | kubectl apply -f -
  envsubst < "$K8S_BASE_DIR/external-dns.yaml" | kubectl apply -f -

  kubectl rollout status deployment/external-dns -n default --timeout=180s
fi

kubectl rollout status deployment/tasks-api -n "$K8S_NAMESPACE" --timeout=180s

echo "Deployment completed."
kubectl get service tasks-api -n "$K8S_NAMESPACE"

if [[ "$DEPLOY_EDGE_RESOURCES" == "true" ]]; then
  echo
  kubectl get gateway tasks-api-gateway -n default
  echo
  kubectl get httproute tasks-api-http-redirect -n default
  echo
  kubectl get httproute tasks-api-route -n default
fi
