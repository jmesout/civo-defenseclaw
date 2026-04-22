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
# System updates & base packages
# -----------------------------------------------------------------------------
log "Updating system packages"
apt-get update -y
apt-get upgrade -y
apt-get install -y curl git ca-certificates build-essential python3 python3-venv python3-pip python3-yaml jq

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
# The upstream installer has a checksum bug (grep substring-match
# double-includes *.sbom.json lines), so we fetch artefacts directly and
# verify the one hash that checksums.txt does publish.
# -----------------------------------------------------------------------------
DEFENSECLAW_VERSION="0.2.0"

log "Installing DefenseClaw gateway v$${DEFENSECLAW_VERSION}"

# Fetch uv installer to disk first — piping `curl | sh` into a no-TTY login
# shell trips SIGPIPE and "curl: (23) Failure writing output to destination".
curl -LsSf https://astral.sh/uv/install.sh -o /tmp/uv-install.sh
chmod +x /tmp/uv-install.sh

su - civo -c "set -e
  mkdir -p \$HOME/.local/bin \$HOME/.defenseclaw/extensions
  cd /tmp

  # uv (installs to ~/.local/bin and writes the 'env' shim used below)
  sh /tmp/uv-install.sh --quiet </dev/null

  # Gateway binary (with sha256 verification)
  curl -sSfL -o dc.tar.gz \"https://github.com/cisco-ai-defense/defenseclaw/releases/download/$${DEFENSECLAW_VERSION}/defenseclaw_$${DEFENSECLAW_VERSION}_linux_amd64.tar.gz\"
  expected=\$(curl -sSfL \"https://github.com/cisco-ai-defense/defenseclaw/releases/download/$${DEFENSECLAW_VERSION}/checksums.txt\" | grep -E \"  defenseclaw_$${DEFENSECLAW_VERSION}_linux_amd64.tar.gz\\\$\" | awk '{print \$1}')
  actual=\$(sha256sum dc.tar.gz | awk '{print \$1}')
  [ \"\$expected\" = \"\$actual\" ] || { echo 'DefenseClaw gateway sha256 mismatch'; exit 1; }
  tar -xzf dc.tar.gz
  install -m 755 defenseclaw \$HOME/.local/bin/defenseclaw-gateway

  # CLI (Python wheel via uv tool)
  curl -sSfL -o defenseclaw-$${DEFENSECLAW_VERSION}-py3-none-any.whl \"https://github.com/cisco-ai-defense/defenseclaw/releases/download/$${DEFENSECLAW_VERSION}/defenseclaw-$${DEFENSECLAW_VERSION}-py3-none-any.whl\"
  . \$HOME/.local/bin/env
  uv tool install --force /tmp/defenseclaw-$${DEFENSECLAW_VERSION}-py3-none-any.whl

  # OpenClaw extension plugin (no sha published upstream).
  # Install via OpenClaw's own installer so the plugin is registered and
  # loaded by the gateway. OpenClaw's plugin scanner flags DefenseClaw
  # because it uses child_process (needed for scanning other plugins),
  # so we pass --dangerously-force-unsafe-install to bypass the check.
  curl -sSfL -o dc-plugin.tar.gz \"https://github.com/cisco-ai-defense/defenseclaw/releases/download/$${DEFENSECLAW_VERSION}/defenseclaw-plugin-$${DEFENSECLAW_VERSION}.tar.gz\"
  export PATH=\$HOME/.npm-global/bin:\$PATH
  openclaw plugins install /tmp/dc-plugin.tar.gz --force --dangerously-force-unsafe-install

  # The installer writes a restrictive plugins.allow=[defenseclaw,…] which
  # disables the bundled OpenClaw CLI plugins (capability, agent, …).
  # Drop the key so all discovered plugins auto-load permissively.
  tmp=\$(mktemp)
  jq 'if has(\"plugins\") then .plugins |= del(.allow) else . end' \$HOME/.openclaw/openclaw.json > \$tmp
  mv \$tmp \$HOME/.openclaw/openclaw.json
  chmod 600 \$HOME/.openclaw/openclaw.json
"

log "Initialising DefenseClaw"
su - civo -c '. $HOME/.local/bin/env && $HOME/.local/bin/defenseclaw init </dev/null' || true

# -----------------------------------------------------------------------------
# Configure OpenClaw
# -----------------------------------------------------------------------------
log "Configuring OpenClaw"

OPENCLAW_HOME="/home/civo"
OPENCLAW_STATE="$OPENCLAW_HOME/.openclaw"

mkdir -p "$OPENCLAW_STATE" "$OPENCLAW_STATE/workspace"

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

chmod 600 "$OPENCLAW_STATE/openclaw.json" "$OPENCLAW_STATE/.env"
chown -R civo:civo "$OPENCLAW_STATE"

# -----------------------------------------------------------------------------
# Configure DefenseClaw: wire the gateway auth token and seed guardrail config
# so `defenseclaw setup guardrail --non-interactive` can succeed.
# -----------------------------------------------------------------------------
log "Wiring DefenseClaw to OpenClaw (auth + guardrail seed)"

cat > /home/civo/.defenseclaw/.env <<ENVEOF
OPENCLAW_GATEWAY_TOKEN=${openclaw_gateway_token}
RELAX_API_KEY=${relax_api_key}
ENVEOF
chmod 600 /home/civo/.defenseclaw/.env
chown civo:civo /home/civo/.defenseclaw/.env

su - civo -c 'python3 - <<PY
import yaml
p = "/home/civo/.defenseclaw/config.yaml"
c = yaml.safe_load(open(p))
c.setdefault("gateway", {})["token_env"] = "OPENCLAW_GATEWAY_TOKEN"
c.setdefault("inspect_llm", {}).update({
    "provider": "openai",
    "model": "${relax_model}",
    "api_key_env": "RELAX_API_KEY",
    "base_url": "https://api.relax.ai/v1",
})
c.setdefault("guardrail", {}).update({
    "enabled": True,
    "mode": "action",
    "scanner_mode": "local",
    "port": 18889,
    "model": "openai/${relax_model}",
    "model_name": "${relax_model}",
    "api_key_env": "RELAX_API_KEY",
    "original_model": "relax/${relax_model}",
})
yaml.safe_dump(c, open(p, "w"), default_flow_style=False, sort_keys=False)
PY'

# -----------------------------------------------------------------------------
# Systemd: DefenseClaw gateway (foreground; no args = daemon in-process)
# -----------------------------------------------------------------------------
log "Creating defenseclaw-gateway systemd service"
cat > /etc/systemd/system/defenseclaw-gateway.service <<'SERVICEEOF'
[Unit]
Description=DefenseClaw Gateway
After=network-online.target openclaw.service
Wants=network-online.target

[Service]
Type=simple
User=civo
WorkingDirectory=/home/civo
EnvironmentFile=/home/civo/.defenseclaw/.env
ExecStart=/home/civo/.local/bin/defenseclaw-gateway
Restart=always
RestartSec=5

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
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=civo
WorkingDirectory=/home/civo
ExecStart=/home/civo/.npm-global/bin/openclaw gateway
Restart=always
RestartSec=5
EnvironmentFile=/home/civo/.openclaw/.env

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable --now openclaw
log "OpenClaw gateway started"

systemctl enable --now defenseclaw-gateway
log "DefenseClaw gateway started"

# Wait for OpenClaw to accept connections before patching its config
for i in $(seq 1 20); do
  if curl -sS -m 2 http://127.0.0.1:18789/health >/dev/null 2>&1; then
    log "OpenClaw gateway responding on :18789"
    break
  fi
  sleep 2
done

# -----------------------------------------------------------------------------
# Enable the DefenseClaw guardrail — patches OpenClaw config and restarts
# both services. Runs non-interactively since config.yaml is fully seeded.
# -----------------------------------------------------------------------------
log "Enabling DefenseClaw guardrail (action mode, local scanner)"
su - civo -c '. $HOME/.local/bin/env && $HOME/.local/bin/defenseclaw setup guardrail --mode action --scanner-mode local --non-interactive --restart --no-verify' \
  2>&1 | tee -a /var/log/openclaw-init.log \
  || log "WARN: guardrail setup returned non-zero; see above and run 'defenseclaw-gateway status'"

log "Cloud-init provisioning complete"
