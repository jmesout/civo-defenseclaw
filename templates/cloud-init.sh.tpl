#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

log() { echo "[defenseclaw-init] $(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a /var/log/openclaw-init.log; }

log "Starting cloud-init provisioning"

# -----------------------------------------------------------------------------
# System updates
# -----------------------------------------------------------------------------
log "Updating system packages"
apt-get update -y
apt-get upgrade -y
apt-get install -y curl git ca-certificates build-essential python3 python3-venv python3-pip

# -----------------------------------------------------------------------------
# Install Node.js 22
# -----------------------------------------------------------------------------
log "Installing Node.js 22"
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

# -----------------------------------------------------------------------------
# Create openclaw user and authorise the operator SSH key
# -----------------------------------------------------------------------------
log "Creating openclaw user"
useradd -m -s /bin/bash openclaw || true

install -d -m 700 -o openclaw -g openclaw /home/openclaw/.ssh
cat > /home/openclaw/.ssh/authorized_keys <<KEYEOF
${ssh_public_key}
KEYEOF
chmod 600 /home/openclaw/.ssh/authorized_keys
chown openclaw:openclaw /home/openclaw/.ssh/authorized_keys

# Allow the openclaw user to manage its own systemd units without a password
cat > /etc/sudoers.d/openclaw <<'SUDOEOF'
openclaw ALL=(root) NOPASSWD: /bin/systemctl
SUDOEOF
chmod 440 /etc/sudoers.d/openclaw

# -----------------------------------------------------------------------------
# Install OpenClaw (as the openclaw user)
# -----------------------------------------------------------------------------
log "Installing OpenClaw"
su - openclaw -c 'curl -fsSL https://openclaw.ai/install.sh | bash'

# -----------------------------------------------------------------------------
# Install DefenseClaw (gateway + CLI + OpenClaw plugin)
# -----------------------------------------------------------------------------
log "Installing DefenseClaw"
su - openclaw -c 'curl -LsSf https://raw.githubusercontent.com/cisco-ai-defense/defenseclaw/main/scripts/install.sh | bash -s -- --yes'
su - openclaw -c '$HOME/.local/bin/defenseclaw init --enable-guardrail --yes'

# -----------------------------------------------------------------------------
# Configure OpenClaw
# -----------------------------------------------------------------------------
log "Configuring OpenClaw"

OPENCLAW_HOME="/home/openclaw"
OPENCLAW_STATE="$OPENCLAW_HOME/.openclaw"

mkdir -p "$OPENCLAW_STATE"
mkdir -p "$OPENCLAW_STATE/workspace"

cat > "$OPENCLAW_STATE/openclaw.json" <<'CONFIGEOF'
{
  "gateway": {
    "port": 18789,
    "bind": "127.0.0.1",
    "mode": "full"
  },
  "models": {
    "providers": {
      "relax": {
        "baseUrl": "https://api.relax.ai/v1",
        "apiKey": "$${RELAX_API_KEY}",
        "api": "openai-completions"
      }
    }
  },
  "agents": {
    "defaults": {
      "workspace": "~/.openclaw/workspace",
      "model": {
        "primary": "relax/default"
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
  },
  "security": {
    "requireAuth": true
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
chown -R openclaw:openclaw "$OPENCLAW_STATE"

# -----------------------------------------------------------------------------
# Systemd: DefenseClaw gateway
# -----------------------------------------------------------------------------
log "Creating defenseclaw-gateway systemd service"
cat > /etc/systemd/system/defenseclaw-gateway.service <<'SERVICEEOF'
[Unit]
Description=DefenseClaw Gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=openclaw
WorkingDirectory=/home/openclaw
ExecStart=/home/openclaw/.local/bin/defenseclaw-gateway start
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICEEOF

# -----------------------------------------------------------------------------
# Systemd: OpenClaw gateway
# -----------------------------------------------------------------------------
log "Creating openclaw systemd service"
cat > /etc/systemd/system/openclaw.service <<'SERVICEEOF'
[Unit]
Description=OpenClaw AI Gateway
After=network-online.target defenseclaw-gateway.service
Wants=network-online.target

[Service]
Type=simple
User=openclaw
WorkingDirectory=/home/openclaw
ExecStart=/home/openclaw/.local/bin/openclaw gateway
Restart=on-failure
RestartSec=10
EnvironmentFile=/home/openclaw/.openclaw/.env

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

# -----------------------------------------------------------------------------
# Register the DefenseClaw guardrail plugin with OpenClaw
# -----------------------------------------------------------------------------
log "Registering DefenseClaw guardrail plugin in OpenClaw"
su - openclaw -c '$HOME/.local/bin/defenseclaw setup guardrail --mode action --restart --yes' || \
  log "WARN: defenseclaw setup guardrail returned non-zero; inspect manually with 'defenseclaw status'"

log "Cloud-init provisioning complete"
