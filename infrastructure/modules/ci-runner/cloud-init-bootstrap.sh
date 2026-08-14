#cloud-config

package_update: true

packages:
  - docker.io
  - docker-compose-v2
  - curl
  - wget
  - unzip
  - jq
  - git
  - openjdk-17-jre-headless
  - ca-certificates
  - apt-transport-https
  - python3-pip
  - openssl

write_files:
  - path: /usr/local/bin/bootstrap-ci-runner.sh
    permissions: "0755"
    owner: ${admin_username}:${admin_username}
    content: |
      #!/usr/bin/env bash
      set -euo pipefail

      log() {
        printf '[ci-runner-bootstrap] %s\n' "$1"
      }

      retry() {
        local attempts="$1"
        local delay_seconds="$2"
        shift 2

        local attempt=1

        until "$@"; do
          if [[ "$attempt" -ge "$attempts" ]]; then
            return 1
          fi

          log "retry $attempt/$attempts failed for: $*"
          attempt=$((attempt + 1))
          sleep "$delay_seconds"
        done
      }

      ADMIN_USERNAME="${admin_username}"
      KEY_VAULT_NAME="${key_vault_name}"
      GITHUB_PAT_SECRET_NAME="${github_runner_pat_secret_name}"
      SONAR_DB_PASSWORD_SECRET_NAME="${sonarqube_db_password_secret_name}"
      GITHUB_OWNER="${github_org}"
      GITHUB_REPO="${github_repo}"

      RUNNER_DIR="/opt/github-runner"
      SONAR_DIR="/opt/sonarqube"

      # ============================================================
      # System configuration required by SonarQube
      # ============================================================

      sysctl -w vm.max_map_count=524288
      sysctl -w fs.file-max=131072

      cat >/etc/sysctl.d/99-sonarqube.conf <<'SYSCTL'
      vm.max_map_count=524288
      fs.file-max=131072
      SYSCTL

      # ============================================================
      # Docker
      # ============================================================

      log "waiting for docker daemon"
      retry 30 5 docker info >/dev/null 2>&1

      usermod -aG docker "$ADMIN_USERNAME"

      # ============================================================
      # Azure Managed Identity
      # ============================================================

      log "logging in with managed identity"

      retry 30 10 \
        az login --identity --allow-no-subscriptions >/dev/null

      # ============================================================
      # Retrieve GitHub PAT from Key Vault
      # ============================================================

      log "retrieving GitHub PAT from Key Vault"

      GITHUB_PAT="$(retry 30 10 \
        az keyvault secret show \
          --vault-name "$KEY_VAULT_NAME" \
          --name "$GITHUB_PAT_SECRET_NAME" \
          --query value \
          -o tsv)"

      if [[ -z "$GITHUB_PAT" ]]; then
        echo "GitHub PAT secret '$GITHUB_PAT_SECRET_NAME' was empty or missing in Key Vault '$KEY_VAULT_NAME'" >&2
        exit 1
      fi

      # ============================================================
      # Retrieve SonarQube PostgreSQL password from Key Vault
      # ============================================================

      log "retrieving SonarQube DB password from Key Vault"

      SONAR_DB_PASSWORD="$(retry 30 10 \
        az keyvault secret show \
          --vault-name "$KEY_VAULT_NAME" \
          --name "$SONAR_DB_PASSWORD_SECRET_NAME" \
          --query value \
          -o tsv)"

      if [[ -z "$SONAR_DB_PASSWORD" ]]; then
        echo "SonarQube DB password secret '$SONAR_DB_PASSWORD_SECRET_NAME' was empty or missing in Key Vault '$KEY_VAULT_NAME'" >&2
        exit 1
      fi

      # ============================================================
      # Create directories
      # ============================================================

      mkdir -p "$SONAR_DIR"
      mkdir -p "$RUNNER_DIR"

      chown -R "$ADMIN_USERNAME:$ADMIN_USERNAME" \
        "$SONAR_DIR" \
        "$RUNNER_DIR"

      # ============================================================
      # SonarQube environment
      # ============================================================

      cat >"$SONAR_DIR/.env" <<EOF
      SONAR_DB_PASSWORD=$SONAR_DB_PASSWORD
      EOF

      chmod 600 "$SONAR_DIR/.env"

      # ============================================================
      # SonarQube Docker Compose
      # ============================================================

      cat >"$SONAR_DIR/docker-compose.yaml" <<'EOF'
      services:

        sonarqube-db:
          image: postgres:17-alpine
          restart: unless-stopped
          environment:
            POSTGRES_USER: sonar
            POSTGRES_PASSWORD: $${SONAR_DB_PASSWORD}
            POSTGRES_DB: sonarqube
          volumes:
            - sonarqube-db:/var/lib/postgresql/data

        sonarqube:
          image: sonarqube:26.8.0.126808-community
          restart: unless-stopped
          depends_on:
            - sonarqube-db
          ports:
            - "9000:9000"
          environment:
            SONAR_JDBC_URL: jdbc:postgresql://sonarqube-db:5432/sonarqube
            SONAR_JDBC_USERNAME: sonar
            SONAR_JDBC_PASSWORD: $${SONAR_DB_PASSWORD}
          volumes:
            - sonarqube-data:/opt/sonarqube/data
            - sonarqube-extensions:/opt/sonarqube/extensions
            - sonarqube-logs:/opt/sonarqube/logs

      volumes:
        sonarqube-db:
        sonarqube-data:
        sonarqube-extensions:
        sonarqube-logs:
      EOF

      # ============================================================
      # Start SonarQube
      # ============================================================

      log "starting SonarQube containers"

      docker compose \
        --project-directory "$SONAR_DIR" \
        -f "$SONAR_DIR/docker-compose.yaml" \
        up -d

      # ============================================================
      # Download GitHub Actions runner
      # ============================================================

      if [[ ! -f "$RUNNER_DIR/run.sh" ]]; then

        log "downloading GitHub Actions runner"

        RUNNER_VERSION="$(curl -fsSL \
          https://api.github.com/repos/actions/runner/releases/latest \
          | jq -r '.tag_name' \
          | sed 's/^v//')"

        curl -fsSL \
          "https://github.com/actions/runner/releases/download/v$RUNNER_VERSION/actions-runner-linux-x64-$RUNNER_VERSION.tar.gz" \
          -o "$RUNNER_DIR/runner.tgz"

        tar xzf "$RUNNER_DIR/runner.tgz" \
          -C "$RUNNER_DIR"

        rm -f "$RUNNER_DIR/runner.tgz"

        "$RUNNER_DIR/bin/installdependencies.sh"

        chown -R \
          "$ADMIN_USERNAME:$ADMIN_USERNAME" \
          "$RUNNER_DIR"

      else

        log "GitHub Actions runner already downloaded"

      fi

      # ============================================================
      # GitHub runner registration token
      # ============================================================

      log "minting GitHub runner registration token"

      REGISTRATION_TOKEN="$(curl -fsSL \
        -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $GITHUB_PAT" \
        "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/actions/runners/registration-token" \
        | jq -r '.token')"

      if [[ -z "$REGISTRATION_TOKEN" || "$REGISTRATION_TOKEN" == "null" ]]; then
        echo "Failed to mint a GitHub runner registration token for $GITHUB_OWNER/$GITHUB_REPO" >&2
        exit 1
      fi

      # ============================================================
      # Configure GitHub Actions runner
      # ============================================================

      if [[ -f "$RUNNER_DIR/.runner" ]]; then

        log "GitHub Actions runner already configured; skipping config.sh"

      else

        log "configuring GitHub Actions runner"

        sudo -u "$ADMIN_USERNAME" \
          "$RUNNER_DIR/config.sh" \
          --url "https://github.com/$GITHUB_OWNER/$GITHUB_REPO" \
          --token "$REGISTRATION_TOKEN" \
          --name "$(hostname)-runner" \
          --work "_work" \
          --unattended \
          --replace

      fi

      # ============================================================
      # Install/start GitHub Actions runner service
      # ============================================================

      log "installing and starting runner service"

      cd "$RUNNER_DIR"

      # unit filename depends on org/repo/hostname, so glob instead of a fixed name
      if ls /etc/systemd/system/actions.runner.*.service >/dev/null 2>&1; then

        log "GitHub Actions runner service unit already exists; skipping install"

      else

        if ! ./svc.sh install "$ADMIN_USERNAME"; then
          log "svc.sh install failed (likely already exists); skipping and continuing"
        fi

      fi

      if ! ./svc.sh start; then
        log "svc.sh start failed; skipping and continuing"
      fi

      cd /

      # ============================================================
      # Install SonarQube Scanner
      # ============================================================

      SONAR_SCANNER_VERSION="7.1.0.4889"

      if [[ ! -x "/opt/sonar-scanner-$SONAR_SCANNER_VERSION-linux-x64/bin/sonar-scanner" ]]; then

        log "installing SonarQube scanner"

        curl -fsSL \
          "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-$SONAR_SCANNER_VERSION-linux-x64.zip" \
          -o /tmp/sonar-scanner.zip

        unzip -q \
          /tmp/sonar-scanner.zip \
          -d /opt

        rm -f /tmp/sonar-scanner.zip

      fi

      ln -sfn \
        "/opt/sonar-scanner-$SONAR_SCANNER_VERSION-linux-x64/bin/sonar-scanner" \
        /usr/local/bin/sonar-scanner

      # ============================================================
      # Python test dependencies
      # ============================================================

      log "installing Python test dependencies"

      pip3 install \
        --no-cache-dir \
        --break-system-packages \
        pytest \
        httpx \
        pytest-cov

      # ============================================================
      # Wait for SonarQube
      #
      # IMPORTANT:
      # SonarQube can return HTTP 403 while still being alive.
      # We only need to verify that port 9000 is accepting connections.
      # ============================================================

      log "waiting for SonarQube"

      SONAR_READY=false

      for i in $(seq 1 60); do

        if curl -sS \
          --connect-timeout 2 \
          --max-time 5 \
          http://127.0.0.1:9000/ \
          >/dev/null 2>&1; then

          log "SonarQube is responding"
          SONAR_READY=true
          break

        fi

        log "SonarQube not ready yet ($i/60)"
        sleep 5

      done

      if [[ "$SONAR_READY" != "true" ]]; then

        log "SonarQube failed to become ready"

        docker compose \
          --project-directory "$SONAR_DIR" \
          -f "$SONAR_DIR/docker-compose.yaml" \
          ps

        docker compose \
          --project-directory "$SONAR_DIR" \
          -f "$SONAR_DIR/docker-compose.yaml" \
          logs \
          --tail=100

        exit 1

      fi

      # ============================================================
      # Done
      # ============================================================

      echo "CI runner bootstrap complete at $(date -Iseconds)" \
        >> /var/log/ci-runner-bootstrap.log

      log "CI runner bootstrap completed successfully"

runcmd:
  - systemctl enable docker
  - systemctl start docker
  - curl -sL https://aka.ms/InstallAzureCLIDeb | bash
  - az aks install-cli
  - curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  - /usr/local/bin/bootstrap-ci-runner.sh
