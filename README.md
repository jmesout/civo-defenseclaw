# civo-defenseclaw

Terraform stack that stands up an **OpenClaw** agent gateway on [Civo](https://civo.com/) — backed by [Relax.ai](https://relax.ai) for completions, and governed end-to-end by [**Cisco DefenseClaw**](https://github.com/cisco-ai-defense/defenseclaw). Every LLM call and tool call OpenClaw makes is routed through DefenseClaw's guardrail proxy and inspected before it leaves the box.

Forked in spirit from [`jmesout/civo-openclaw`](https://github.com/jmesout/civo-openclaw) — Tailscale and Coder have been stripped, DefenseClaw has been added.

## What you get

```
  operator laptop ── ssh(22) ──► Civo instance (public IP, firewall allowlist)
                                   ├── defenseclaw-gateway.service  (REST :8765)
                                   ├── openclaw.service             (gateway :18789, loopback)
                                   └── DefenseClaw OpenClaw plugin
                                          patches fetch() → guardrail proxy
                                                 │
                                                 ▼
                                          Relax.ai (api.relax.ai/v1)
```

- **OpenClaw** runs as a systemd service on port `18789`, bound to `127.0.0.1`.
- **DefenseClaw gateway** runs as a systemd service on port `8765`, bound to `127.0.0.1`.
- **Firewall** only permits inbound SSH from `var.ssh_allowed_cidr`. All other ingress is denied.
- **DefenseClaw guardrail** is registered in `action` mode — HIGH/CRITICAL findings auto-block, MEDIUM/LOW generate warnings.
- Reach OpenClaw and DefenseClaw from your laptop via an SSH tunnel (`terraform output gateway_tunnel_command`).

## Prerequisites

| Thing | Where |
|-------|-------|
| Civo API token | <https://dashboard.civo.com/security> |
| Relax.ai API key | <https://relax.ai> |
| SSH keypair | `ssh-keygen -t ed25519` |
| Your source IP (for the firewall) | `curl -4 ifconfig.io` |
| Terraform | `>= 1.5.0` |
| (Optional) Slack bot + app token | <https://api.slack.com/apps> |

## Quick start

```bash
git clone https://github.com/jmesout/civo-defenseclaw.git
cd civo-defenseclaw

cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars           # fill in every REPLACE_ME

terraform init
terraform apply
```

Provisioning takes ~5–10 minutes. When the apply finishes, Terraform prints the SSH command and tunnel command.

## Variables

| Variable | Purpose |
|----------|---------|
| `civo_api_token` | Civo API token |
| `civo_region` | Civo region (default `LON1`) |
| `civo_instance_size` | Instance size (default `g3.small`; bump to `g3.medium` if tight) |
| `civo_disk_image` | Image filter (default `ubuntu-noble`) |
| `hostname` | Hostname on Civo (default `defenseclaw`) |
| `ssh_public_key` | Your SSH public key, authorised for the `openclaw` user |
| `ssh_allowed_cidr` | CIDR list allowed on port 22, e.g. `["203.0.113.5/32"]` |
| `relax_api_key` | Relax.ai API key used as OpenClaw's model backend |
| `openclaw_gateway_token` | Bearer token for the OpenClaw gateway |
| `slack_bot_token` | Optional Slack `xoxb-…` token |
| `slack_app_token` | Optional Slack `xapp-…` token (required if the bot token is set) |

## Using OpenClaw

Open the tunnel, then point your client at `http://localhost:18789`:

```bash
$(terraform output -raw gateway_tunnel_command)

# In another terminal:
curl -H "Authorization: Bearer $OPENCLAW_GATEWAY_TOKEN" \
     http://localhost:18789/health
```

OpenClaw is configured to send completions to Relax.ai as provider `relax/default`.

## Using DefenseClaw

DefenseClaw's CLI is installed alongside OpenClaw under `/home/openclaw/.local/bin`. SSH in and run:

```bash
ssh openclaw@$(terraform output -raw instance_public_ip)

defenseclaw status                  # gateway + guardrail health
defenseclaw alerts -n 20            # recent enforcement events
defenseclaw skill scan <name>       # scan a skill before install
defenseclaw mcp scan <name>         # scan an MCP server
defenseclaw tool block <tool>       # deny a tool
defenseclaw tool allow <tool>       # allow a tool
```

Config lives at `~/.defenseclaw/config.yaml`; the audit store is `~/.defenseclaw/audit.db`. Changes apply without restart.

The REST API is also forwarded by the tunnel command:

```bash
curl http://localhost:8765/api/v1/status
```

## Security notes

- Instance has a public IP; the Civo firewall denies everything except SSH from your CIDR and outbound 80/443/53.
- OpenClaw (`18789`) and DefenseClaw (`8765`) listen on `127.0.0.1` only. They are never exposed publicly, even accidentally.
- OpenSSH is left enabled (it's the only way in now that Tailscale is gone). Keep `ssh_allowed_cidr` narrow.
- The gateway token is still required on OpenClaw's HTTP surface.
- The upstream installers (`openclaw.ai/install.sh`, `cisco-ai-defense/defenseclaw/main/scripts/install.sh`) are fetched from `main` — pin versions before using this anywhere near production.

## Teardown

```bash
terraform destroy
```

Removes the instance, firewall, and network. Nothing persists in Civo.
