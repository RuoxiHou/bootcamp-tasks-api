# Self-Hosted GitHub Runner and SonarQube

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
     -> deploy to AKS staging
     -> smoke tests
     -> manual approval
     -> deploy to production
     -> rollback on failure
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

Sensitive values are not hardcoded in Terraform or cloud-init.

- GitHub runner bootstrap auth:
  Store a GitHub token in Key Vault under the secret name in `github_runner_pat_secret_name`.
  The VM reads it with its managed identity and uses it only to request a short-lived runner registration token.
- SonarQube database password:
  Generated locally on first boot and written only to `/opt/sonarqube/.env` on the VM.
- GitHub repository secrets still required:
  `SONAR_TOKEN` and `CERT_MANAGER_EMAIL`

## Required Key Vault secret

Create this secret before provisioning or reprovisioning the VM:

```bash
az keyvault secret set \
  --vault-name <key-vault-name> \
  --name github-runner-pat \
  --value '<github-token>'
```

The token must be able to create repository runner registration tokens for the target repo.

## Required tfvars inputs

```hcl
ssh_public_key                = "ssh-rsa AAAA..."
admin_source_ip               = "YOUR_IP/32"
github_org                    = "RuoxiHou"
github_repo                   = "bootcamp-tasks-api"
github_runner_pat_secret_name = "github-runner-pat"
```

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

- `test-quality`: pytest plus SonarQube scan on the runner VM.
- `build-push`: logs into Azure with managed identity, reads ACR values from remote state, builds, tags, and pushes the image.
- `deploy-staging`: deploys the app into the `staging` namespace without edge resources.
- `smoke-tests`: uses `kubectl port-forward` against the staging service and checks `/health`, `/metrics`, and `/tasks`.
- `approval`: GitHub environment gate for production.
- `deploy-production`: deploys to `default` and applies edge resources.
- `rollback`: runs `kubectl rollout undo` if production deployment fails.

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
3. Change password (required)
4. Create a project:
   - Name: `bootcamp-tasks-api`
   - Key: `bootcamp-tasks-api`
5. Generate authentication token:
   - Administration → Security → Users → Tokens
   - Copy token and add to GitHub secrets as `SONAR_TOKEN`

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
   git push origin main
   ```

2. Monitor the workflow:
   - GitHub → Actions → CI/CD Pipeline
   - Watch each stage execute

3. Approve production deployment:
   - GitHub will wait at the "Manual Approval" stage
   - Click "Approve and run"

4. Monitor production health:
   ```bash
   kubectl get pods -n default -l app=tasks-api
   kubectl logs -n default deployment/tasks-api -f
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
