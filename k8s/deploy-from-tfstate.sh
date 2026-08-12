#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_DIR="$ROOT_DIR/infrastructure"
K8S_BASE_DIR="$ROOT_DIR/k8s/base"
CERT_MANAGER_VERSION="v1.16.5"

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

if ! kubectl get gatewayclass approuting-istio >/dev/null 2>&1; then
  echo "GatewayClass 'approuting-istio' not found. Enable AKS application routing first." >&2
  exit 1
fi

# Read deployment values from Terraform state outputs.
KEY_VAULT_NAME="$(terraform -chdir="$INFRA_DIR" output -raw key_vault_name)"
WORKLOAD_IDENTITY_CLIENT_ID="$(terraform -chdir="$INFRA_DIR" output -raw workload_identity_client_id)"
AZURE_TENANT_ID="$(terraform -chdir="$INFRA_DIR" output -raw tenant_id)"
AZURE_SUBSCRIPTION_ID="$(terraform -chdir="$INFRA_DIR" output -raw subscription_id)"
EXTERNALDNS_CLIENT_ID="$(terraform -chdir="$INFRA_DIR" output -raw externaldns_client_id)"
AZURE_DNS_RESOURCE_GROUP="$(terraform -chdir="$INFRA_DIR" output -raw resource_group_name)"
DNS_ZONE_NAME="$(terraform -chdir="$INFRA_DIR" output -raw dns_zone_name)"
TASKS_API_HOSTNAME="api.${DNS_ZONE_NAME}"

export KEY_VAULT_NAME
export WORKLOAD_IDENTITY_CLIENT_ID
export AZURE_TENANT_ID
export AZURE_SUBSCRIPTION_ID
export EXTERNALDNS_CLIENT_ID
export AZURE_DNS_RESOURCE_GROUP
export DNS_ZONE_NAME
export TASKS_API_HOSTNAME

if [ -z "${CERT_MANAGER_EMAIL:-}" ]; then
  echo "ERROR: CERT_MANAGER_EMAIL must be set for cert-manager ClusterIssuer" >&2
  exit 1
fi
export CERT_MANAGER_EMAIL

# Apply resources in dependency order.
envsubst < "$K8S_BASE_DIR/tasks-api-serviceaccount.yaml" | kubectl apply -f -
envsubst < "$K8S_BASE_DIR/tasks-api-secret-provider.yaml" | kubectl apply -f -

kubectl apply -f "$K8S_BASE_DIR/tasks-api-service.yaml"
kubectl apply -f "$K8S_BASE_DIR/tasks-api-deployment.yaml"

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

kubectl rollout status deployment/cert-manager \
  -n cert-manager --timeout=180s

kubectl rollout status deployment/cert-manager-webhook \
  -n cert-manager --timeout=180s

kubectl rollout status deployment/cert-manager-cainjector \
  -n cert-manager --timeout=180s

envsubst < "$K8S_BASE_DIR/cert-manager-issuer.yaml" | kubectl apply -f -
envsubst < "$K8S_BASE_DIR/cert-manager-certificate.yaml" | kubectl apply -f -

kubectl apply -f "$K8S_BASE_DIR/tasks-api-gateway.yaml"
envsubst < "$K8S_BASE_DIR/tasks-api-httproute.yaml" | kubectl apply -f -

kubectl apply -f "$K8S_BASE_DIR/external-dns-rbac.yaml"
envsubst < "$K8S_BASE_DIR/external-dns-serviceaccount.yaml" | kubectl apply -f -
envsubst < "$K8S_BASE_DIR/external-dns-azure-config.yaml" | kubectl apply -f -
envsubst < "$K8S_BASE_DIR/external-dns.yaml" | kubectl apply -f -

kubectl rollout status deployment/external-dns -n default --timeout=180s

kubectl rollout status deployment/tasks-api -n default --timeout=180s

echo "Deployment completed."
kubectl get service tasks-api -n default
echo
kubectl get gateway tasks-api-gateway -n default
echo
kubectl get httproute tasks-api-http-redirect -n default
echo
kubectl get httproute tasks-api-route -n default
