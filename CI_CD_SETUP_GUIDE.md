# CI/CD, Self-Hosted Runner, and Observability

## Architecture

```
GitHub
  -> self-hosted runner on Azure VM
     -> pytest
     -> SonarQube scan
     -> docker build
     -> tag with commit SHA
     -> az login --identity
     -> push to ACR
     -> deploy app manifest to AKS default namespace
     -> verify rollout
     -> rollback on failure

Terraform
  -> kube-prometheus-stack (Prometheus, Alertmanager, Grafana)
  -> Loki and Alloy
  -> Tasks API ServiceMonitor, dashboards, and alert rules
```

## What the current implementation does

- Provisions a dedicated CI subnet and a Linux VM for the runner.
- Assigns a system-managed identity to the VM.
- Grants that identity `AcrPush`, `Azure Kubernetes Service Cluster User Role`, and `Key Vault Secrets User`.
- Attaches a public IP and exposes port 9000 for SonarQube, gated by `admin_source_ip`.
- Bootstraps Docker, Azure CLI, kubectl, Helm, SonarScanner, SonarQube, and the GitHub runner through cloud-init.
- Uses the VM’s managed identity in GitHub Actions with `az login --identity`.
- Pulls non-secret deployment values from remote Terraform state with `terraform output`.
- Retrieves the GitHub PAT from Azure Key Vault at VM bootstrap time, then calls GitHub’s runner registration API to mint a short-lived registration token.

## Secrets model

Sensitive values must not be committed to Terraform, workflow, or cloud-init files.

- GitHub runner bootstrap auth:
  Store a GitHub token in Key Vault under the secret name in `github_runner_pat_secret_name`.
  The VM reads it with its managed identity and uses it only to request a short-lived runner registration token.
- SonarQube database password:
   Supply it through a protected Terraform variable and keep the resulting VM file and Terraform state access-restricted.
- GitHub repository secrets still required:
   `SONAR_TOKEN`
- Terraform monitoring secrets:
   Supply the Grafana administrator password and SMTP credentials through a secure local
   tfvars file, `TF_VAR_*` environment variables, or the CI secret store. Do not commit
   passwords or tokens to `terraform.tfvars`.

## Required Key Vault secret

Create this secret before provisioning or reprovisioning the VM:

```bash
az keyvault secret set \
  --vault-name <key-vault-name> \
  --name github-runner-pat \
  --value '<github-token>'
```

The token must be able to create repository runner registration tokens for the target repo.

## Required Terraform inputs

```hcl
ssh_public_key                = "ssh-rsa AAAA..."
admin_source_ip               = "YOUR_IP/32"
github_org                    = "RuoxiHou"
github_repo                   = "bootcamp-tasks-api"
github_runner_pat_secret_name = "github-runner-pat"
```

Supply monitoring secrets outside version control, for example:

```bash
export TF_VAR_grafana_admin_password='<grafana-admin-password>'
export TF_VAR_alert_smtp_smarthost='smtp.gmail.com:587'
export TF_VAR_alert_email_from='<sender-email>'
export TF_VAR_alert_smtp_auth_username='<smtp-username>'
export TF_VAR_alert_smtp_auth_password='<smtp-app-password>'
```

Terraform state can contain sensitive values even when outputs are marked sensitive. Restrict access to the state backend. If real passwords or tokens have previously been committed to a tfvars file, remove them from version control and rotate them.

## Provisioning

```bash
cd infrastructure
terraform init
terraform plan
terraform apply
```

Useful outputs:

```bash
terraform -chdir=infrastructure output -raw ci_runner_public_ip
terraform -chdir=infrastructure output -raw ci_runner_sonarqube_url
```

## Verifying the VM

```bash
RUNNER_IP="$(terraform -chdir=infrastructure output -raw ci_runner_public_ip)"
ssh -i ~/.ssh/id_rsa_azure azureadmin@"$RUNNER_IP"

sudo journalctl -u actions.runner.* -n 100
docker ps
curl http://localhost:9000/api/system/health
```

## GitHub Actions behavior

- The workflow runs for pushes and pull requests targeting `dev`. All three jobs currently run for both event types, so a pull request can build, push, and deploy an image.
- `test-and-sonarqube`: runs pytest with coverage and sends the result to the SonarQube instance on the runner VM.
- `build-and-push`: logs into Azure with the VM managed identity, builds the image, and pushes commit-SHA and `dev` tags to ACR.
- `deploy`: applies `k8s/base/tasks-api-deployment.yaml` to the `default` namespace and waits up to five minutes for rollout.
- If rollout fails, the deploy job runs `kubectl rollout undo`, verifies the rollback, and still marks the workflow as failed.

The workflow deploys only the Tasks API Deployment. It does not run `terraform apply`, install or update the monitoring stack, apply the Service, Gateway, HTTPRoute, secrets, autoscaling resources, or execute endpoint smoke tests. Use Terraform and `k8s/deploy-from-tfstate.sh` for those resources.

## Monitoring and dashboard deployment

The monitoring module owns these resources:

- Prometheus and the Tasks API `ServiceMonitor` for `/metrics`.
- Grafana with Prometheus and Loki datasources.
- Loki and Alloy for Kubernetes log collection.
- `Tasks API Observability` and `Tasks API Business KPIs` dashboard ConfigMaps.
- Alertmanager rules for error rate, p95 latency, and target availability.

Apply infrastructure changes before deploying an app version that adds or renames metrics:

```bash
terraform -chdir=infrastructure init
terraform -chdir=infrastructure plan
terraform -chdir=infrastructure apply
```

Then deploy all Kubernetes application resources when needed:

```bash
export CERT_MANAGER_EMAIL="<email>"
./k8s/deploy-from-tfstate.sh
```

The CI workflow can subsequently update the application image without reinstalling the monitoring stack.

### Verify metrics, logs, dashboards, and alerts

Confirm both application replicas are healthy Prometheus targets:

```bash
kubectl get --raw \
   '/api/v1/namespaces/monitoring/services/http:monitoring-kube-prometheus-prometheus:9090/proxy/api/v1/query?query=up%7Bjob%3D%22tasks-api%22%7D'
```

Confirm the custom dashboards and alerts were applied:

```bash
kubectl get configmap -n monitoring \
   monitoring-grafana-dashboard-tasks-api \
   monitoring-grafana-dashboard-tasks-api-business

kubectl get prometheusrule -n monitoring \
   -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.groups[*].rules[*]}{.alert}{" "}{end}{"\n"}{end}' \
   | grep TasksApi
```

Confirm Loki has recent logs from each Tasks API pod:

```bash
kubectl get --raw \
   '/api/v1/namespaces/monitoring/services/http:loki-gateway:80/proxy/loki/api/v1/query?query=sum%20by%20%28pod%29%20%28count_over_time%28%7Bnamespace%3D%22default%22%2Capp%3D%22tasks-api%22%7D%5B1h%5D%29%29'
```

Grafana remains a `ClusterIP` service, but Gateway API routes its configured subpath through the Tasks API HTTPS listener. Open:

`https://api.ruoxi-projects.space/metrics`

The Tasks API redirects browser requests to the main observability dashboard under `/metrics/grafana`. Grafana requires login; retrieve the generated Kubernetes secret only when needed:

```bash
kubectl get secret monitoring-grafana -n monitoring \
   -o jsonpath='{.data.admin-password}' | base64 -d
echo
```

### `/metrics` behavior

Prometheus must always receive exposition text from `/metrics`. The application can redirect browser requests to Grafana only when `GRAFANA_DASHBOARDS_URL` is configured:

```bash
curl -i -H 'Accept: text/plain' https://api.ruoxi-projects.space/metrics
curl -i -H 'Accept: text/html' https://api.ruoxi-projects.space/metrics
```

The first request returns `200` with Prometheus text. The second returns `307` to the authenticated Grafana dashboard. The more specific `/metrics/grafana` Gateway route sends dashboard traffic to Grafana, while `/metrics` remains backed by the Tasks API for Prometheus. The ServiceMonitor also scrapes the Tasks API service internally, so it never traverses the public Gateway.

## SonarQube access

SonarQube is reachable on the VM public IP at port 9000.

```bash
terraform -chdir=infrastructure output -raw ci_runner_sonarqube_url
```

Default first login is still `admin` / `admin`; change it immediately and create the `SONAR_TOKEN` GitHub secret afterward.

## Notes

- The workflow no longer depends on Azure OIDC secrets such as `AZURE_CLIENT_ID`.
- The deploy script is namespace-aware for app resources and only applies gateway/cert-manager/external-dns resources when `DEPLOY_EDGE_RESOURCES=true`.
- Remote Terraform state remains the source of truth for non-secret runtime values such as ACR login server, AKS name, Key Vault name, and DNS zone.
- Change the default SonarQube administrator password before creating the `bootcamp-tasks-api` project and generating the `SONAR_TOKEN` repository secret.

## GitHub Runner Manual Management

### Check Runner Status

```bash
ssh -i ~/.ssh/id_rsa_azure azureadmin@$RUNNER_IP

# View service status
sudo systemctl status actions-runner

# View service logs
sudo journalctl -u actions-runner -f

# View recent logs
sudo journalctl -u actions-runner -n 50
```

### Restart Runner

```bash
sudo systemctl restart actions-runner
```

### Manual Runner Registration (if needed)

A bootstrap script is available for manual runner setup:

```bash
ssh -i ~/.ssh/id_rsa_azure azureadmin@$RUNNER_IP

# Run the bootstrap script
/opt/github-runner/bootstrap-runner.sh <GITHUB_TOKEN> <GITHUB_ORG> <GITHUB_REPO> [RUNNER_NAME]

# Example
/opt/github-runner/bootstrap-runner.sh my-token RuoxiHou bootcamp-tasks-api custom-runner
```

### Remove Runner Registration

```bash
ssh -i ~/.ssh/id_rsa_azure azureadmin@$RUNNER_IP

cd /opt/github-runner
sudo systemctl stop actions-runner
sudo ./svc.sh uninstall

# Deregister from GitHub (makes it offline)
# The runner will appear as offline in GitHub settings
```

## Troubleshooting

### Runner Not Connecting to GitHub

```bash
# Check runner logs
sudo journalctl -u actions-runner -n 100

# Check if runner is registered
ls -la /opt/github-runner/.runner

# Verify network connectivity to GitHub
curl -I https://api.github.com
```

### SonarQube Not Starting

```bash
# Check docker container status
docker ps -a | grep sonarqube

# View logs
docker logs sonarqube

# Restart SonarQube
cd /opt/sonarqube
docker compose restart

# Wait for health check
curl http://localhost:9000/api/system/health
```

### Managed Identity Issues (ACR/AKS Access)

The runner's managed identity needs:
- `AcrPush` role on ACR
- `Azure Kubernetes Service Cluster User Role` on AKS

Verify:
```bash
# From the runner VM
az acr login --name $ACR_NAME
az aks get-credentials --resource-group $RG_NAME --name $AKS_NAME
```

### Workflow Jobs Running on Wrong Runner

Check `.github/workflows/ci-cd.yaml`:
- All jobs have `runs-on: self-hosted`
- Some jobs also have other labels (optional for filtering)

To run on specific runners, add labels to jobs:
```yaml
jobs:
  test:
    runs-on: [self-hosted, linux]
```

## Security Best Practices

1. **SSH Access**
   - Always use your private key authentication
   - Set `admin_source_ip` to your specific IP or small CIDR range
   - Disable password authentication on VM

2. **GitHub Runner Token**
   - Use time-limited registration tokens when possible
   - Store in GitHub secrets, never in code
   - Rotate tokens periodically

3. **SonarQube Access**
   - Change default admin password immediately
   - Create limited-scope user accounts
   - Use HTTPS in production (configure reverse proxy)

4. **Managed Identity**
   - Never create personal access tokens for automation
   - Use managed identity for Azure resource access
   - Limit role scope to only needed permissions

5. **Secrets Management**
   - Never commit credentials to git
   - Use GitHub secrets for all sensitive values
   - Enable secret scanning on repository

## Cost Optimization

- **Pricing**: Standard_D4s_v5 ~$250/month
- **Optimization**:
  - Use a smaller VM size (Standard_B4ms) if workflows are simple (~$75/month)
  - Schedule VM to stop during non-working hours
  - Use Azure Spot Instances for additional savings (can be interrupted)

```hcl
# In ci-runner module call:
vm_size = "Standard_B4ms"  # Burstable, good for CI/CD
```

## Cleanup & Removal

To remove all CI/CD infrastructure:

```bash
# Remove the runner from GitHub settings first
# Then run:
terraform destroy

# Confirm when prompted
```

## Next Steps

1. Trigger a test deployment:
   ```bash
   git push origin dev
   ```

2. Monitor the workflow:
   - GitHub -> Actions -> CI/CD
   - Watch each stage execute

3. Monitor deployment and observability health:
   ```bash
   kubectl get pods -n default -l app=tasks-api
   kubectl logs -n default deployment/tasks-api -f
   kubectl get servicemonitor -n monitoring tasks-api
   kubectl get configmap -n monitoring -l grafana_dashboard=1
   ```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     GitHub Repository                        │
│                     (Push to main)                           │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────┐
        │  Self-Hosted Runner VM         │
        │  (Azure VM - D4s_v5)           │
        │  ┌──────────────────────────┐  │
        │  │ GitHub Actions Runner    │  │
        │  └──────────────────────────┘  │
        │  ┌──────────────────────────┐  │
        │  │ Docker                   │  │
        │  │ ├─ SonarQube             │  │
        │  │ └─ PostgreSQL            │  │
        │  └──────────────────────────┘  │
        │  ┌──────────────────────────┐  │
        │  │ Tools                    │  │
        │  │ ├─ Azure CLI             │  │
        │  │ ├─ kubectl               │  │
        │  │ ├─ Helm                  │  │
        │  │ └─ Sonar Scanner         │  │
        │  └──────────────────────────┘  │
        └────────────┬───────────────────┘
                     │
        ┌────────────┴──────────────┐
        │                           │
        ▼                           ▼
    ┌─────────────┐          ┌─────────────┐
    │   Azure     │          │   Azure     │
    │ Container   │          │ Kubernetes  │
    │ Registry    │          │ Service     │
    │   (ACR)     │          │   (AKS)     │
    │             │          │             │
    │ Stores      │          │ Runs        │
    │ Docker      │          │ Container   │
    │ Images      │          │ Workloads   │
    └─────────────┘          └─────────────┘
```

## Support & Documentation

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [SonarQube Documentation](https://docs.sonarqube.org/)
- [Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/)
- [GitHub Actions Runner Configuration](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners)
