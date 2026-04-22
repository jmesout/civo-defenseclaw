#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

log() { echo "[defenseclaw-init] $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a /var/log/openclaw-init.log; }

log "Starting cloud-init provisioning"

# -----------------------------------------------------------------------------
# Enable password-based SSH login for the default civo user
# -----------------------------------------------------------------------------
log "Enabling password authentication on sshd"
cat > /etc/ssh/sshd_config.d/10-password-auth.conf <<'SSHEOF'
PasswordAuthentication yes
PubkeyAuthentication yes
SSHEOF

log "Setting civo user password"
echo "civo:${ssh_password}" | chpasswd

systemctl reload ssh || systemctl reload sshd || true

# -----------------------------------------------------------------------------
# System updates
# -----------------------------------------------------------------------------
log "Updating system packages"
apt-get update -y
apt-get upgrade -y
apt-get install -y curl git ca-certificates build-essential python3 python3-venv python3-pip jq

# -----------------------------------------------------------------------------
# Install Node.js 22
# -----------------------------------------------------------------------------
log "Installing Node.js 22"
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

# -----------------------------------------------------------------------------
# Install OpenClaw (as the civo user, non-interactive)
# -----------------------------------------------------------------------------
log "Installing OpenClaw"
su - civo -c 'curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard --no-prompt' </dev/null

# -----------------------------------------------------------------------------
# Install DefenseClaw
# Bypasses the upstream installer's checksum bug (grep substring-match
# double-includes *.sbom.json lines). We fetch the gateway tarball + CLI wheel
# directly from the GitHub release.
# -----------------------------------------------------------------------------
DEFENSECLAW_VERSION="0.2.0"

log "Installing DefenseClaw gateway v$DEFENSECLAW_VERSION"
su - civo -c "set -e
  mkdir -p \$HOME/.local/bin
  cd /tmp
  # uv (pulls Python deps for the CLI wheel)
  curl -LsSf https://astral.sh/uv/install.sh | sh </dev/null
  # Gateway binary
  curl -sSfL -o dc.tar.gz \"https://github.com/cisco-ai-defense/defenseclaw/releases/download/$DEFENSECLAW_VERSION/defenseclaw_$${DEFENSECLAW_VERSION}_linux_amd64.tar.gz\"
  expected=\$(curl -sSfL \"https://github.com/cisco-ai-defense/defenseclaw/releases/download/$DEFENSECLAW_VERSION/checksums.txt\" | grep -E \"  defenseclaw_$${DEFENSECLAW_VERSION}_linux_amd64.tar.gz\\\$\" | awk '{print \$1}')
  actual=\$(sha256sum dc.tar.gz | awk '{print \$1}')
  [ \"\$expected\" = \"\$actual\" ] || { echo 'DefenseClaw gateway sha256 mismatch'; exit 1; }
  tar -xzf dc.tar.gz
  install -m 755 defenseclaw \$HOME/.local/bin/defenseclaw-gateway
  # CLI (Python wheel via uv tool)
  curl -sSfL -o defenseclaw-$${DEFENSECLAW_VERSION}-py3-none-any.whl \"https://github.com/cisco-ai-defense/defenseclaw/releases/download/$DEFENSECLAW_VERSION/defenseclaw-$${DEFENSECLAW_VERSION}-py3-none-any.whl\"
  . \$HOME/.local/bin/env
  uv tool install --force /tmp/defenseclaw-$${DEFENSECLAW_VERSION}-py3-none-any.whl
"

log "Initialising DefenseClaw (skipping interactive guardrail step)"
su - civo -c '. $HOME/.local/bin/env && $HOME/.local/bin/defenseclaw init </dev/null' || true

# -----------------------------------------------------------------------------
# Configure OpenClaw
# -----------------------------------------------------------------------------
log "Configuring OpenClaw"

OPENCLAW_HOME="/home/civo"
OPENCLAW_STATE="$OPENCLAW_HOME/.openclaw"

mkdir -p "$OPENCLAW_STATE"
mkdir -p "$OPENCLAW_STATE/workspace"

cat > "$OPENCLAW_STATE/openclaw.json" <<'CONFIGEOF'
{
  "gateway": {
    "port": 18789,
    "bind": "loopback",
    "mode": "local"
  },
  "models": {
    "providers": {
      "relax": {
        "baseUrl": "https://api.relax.ai/v1",
        "apiKey": "$${RELAX_API_KEY}",
        "api": "openai-completions",
        "models": [{"id": "${relax_model}", "name": "${relax_model}"}]
      }
    }
  },
  "agents": {
    "defaults": {
      "workspace": "~/.openclaw/workspace",
      "model": {
        "primary": "relax/${relax_model}"
      }
    }
  },
  "channels": {
%{ if slack_bot_token != "" ~}
    "slack": {
      "enabled": true,
      "mode": "socket",
      "botToken": "$${SLACK_BOT_TOKEN}",
      "appToken": "$${SLACK_APP_TOKEN}",
      "dmPolicy": "pairing",
      "groupPolicy": "allowlist"
    }
%{ else ~}
    "slack": {
      "enabled": false
    }
%{ endif ~}
  }
}
CONFIGEOF

cat > "$OPENCLAW_STATE/.env" <<ENVEOF
RELAX_API_KEY=${relax_api_key}
OPENCLAW_GATEWAY_TOKEN=${openclaw_gateway_token}
%{ if slack_bot_token != "" ~}
SLACK_BOT_TOKEN=${slack_bot_token}
SLACK_APP_TOKEN=${slack_app_token}
%{ endif ~}
ENVEOF

chmod 600 "$OPENCLAW_STATE/openclaw.json"
chmod 600 "$OPENCLAW_STATE/.env"
chown -R civo:civo "$OPENCLAW_STATE"

# -----------------------------------------------------------------------------
# Systemd: DefenseClaw gateway (Type=forking — the binary daemonises)
# -----------------------------------------------------------------------------
log "Creating defenseclaw-gateway systemd service"
cat > /etc/systemd/system/defenseclaw-gateway.service <<'SERVICEEOF'
[Unit]
Description=DefenseClaw Gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
User=civo
WorkingDirectory=/home/civo
PIDFile=/home/civo/.defenseclaw/gateway.pid
ExecStart=/home/civo/.local/bin/defenseclaw-gateway start
ExecStop=/home/civo/.local/bin/defenseclaw-gateway stop
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICEEOF

# -----------------------------------------------------------------------------
# Systemd: OpenClaw gateway (binary lives under npm-global)
# -----------------------------------------------------------------------------
log "Creating openclaw systemd service"
cat > /etc/systemd/system/openclaw.service <<'SERVICEEOF'
[Unit]
Description=OpenClaw AI Gateway
After=network-online.target defenseclaw-gateway.service
Wants=network-online.target

[Service]
Type=simple
User=civo
WorkingDirectory=/home/civo
ExecStart=/home/civo/.npm-global/bin/openclaw gateway
Restart=on-failure
RestartSec=10
EnvironmentFile=/home/civo/.openclaw/.env

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable defenseclaw-gateway
systemctl start defenseclaw-gateway
log "DefenseClaw gateway started"

systemctl enable openclaw
systemctl start openclaw
log "OpenClaw gateway started"

log "Cloud-init provisioning complete"
log "To enable the DefenseClaw guardrail, ssh in and run:"
log "  defenseclaw setup guardrail  (interactive — pick action mode, local scanner)"
