# civo-defenseclaw

Terraform stack that stands up an **OpenClaw** agent gateway on [Civo](https://civo.com/) — backed by [Relax.ai](https://relax.ai) for completions, and governed end-to-end by [**Cisco DefenseClaw**](https://github.com/cisco-ai-defense/defenseclaw). Every LLM call and tool call OpenClaw makes is routed through DefenseClaw's guardrail proxy and inspected before it leaves the box.

Forked in spirit from [`jmesout/civo-openclaw`](https://github.com/jmesout/civo-openclaw) — Tailscale and Coder have been stripped, DefenseClaw has been added.

## What you get

```
  operator laptop ── ssh(22) ──► Civo instance (public IP)
                                   ├── defenseclaw-gateway.service  (REST :8765, loopback)
                                   ├── openclaw.service             (gateway :18789, loopback)
                                   └── DefenseClaw OpenClaw plugin
                                          patches fetch() → guardrail proxy
                                                 │
                                                 ▼
                                          Relax.ai (api.relax.ai/v1)
```

- **OpenClaw** runs as a systemd service on port `18789`, bound to `127.0.0.1`.
- **DefenseClaw gateway** runs as a systemd service on port `8765`, bound to `127.0.0.1`.
- **Firewall** allows SSH from `var.ssh_allowed_cidr` (default `0.0.0.0/0`; narrow to your source IP for production). All other ingress is denied.
- **SSH** uses Civo's auto-generated password for the default `civo` user — retrieve with `terraform output -raw ssh_password`.
- **DefenseClaw guardrail** is registered in `action` mode — HIGH/CRITICAL findings auto-block, MEDIUM/LOW generate warnings.
- Reach OpenClaw and DefenseClaw from your laptop via an SSH tunnel (`terraform output gateway_tunnel_command`).

## Prerequisites

| Thing | Where |
|-------|-------|
| Civo API token | <https://dashboard.civo.com/security> |
| Relax.ai API key | <https://relax.ai> |
| Terraform | `>= 1.5.0` |
| (Optional) source IP for the firewall | `curl -4 ifconfig.io` |
| (Optional) Slack bot + app token | <https://api.slack.com/apps> |

## Quick start

```bash
git clone https://github.com/jmesout/civo-defenseclaw.git
cd civo-defenseclaw

cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars           # fill in every REPLACE_ME

terraform init
terraform apply

# Retrieve the auto-generated SSH password
terraform output -raw ssh_password
```

Provisioning takes ~5–10 minutes. When the apply finishes, Terraform prints the SSH and tunnel commands.

## Variables

| Variable | Purpose |
|----------|---------|
| `civo_api_token` | Civo API token |
| `civo_region` | Civo region (default `LON1`) |
| `civo_instance_size` | Instance size (default `g3.small`; bump to `g3.medium` if tight) |
| `civo_disk_image` | Image filter (default `ubuntu-noble`) |
| `hostname` | Hostname on Civo (default `defenseclaw`) |
| `ssh_allowed_cidr` | Optional. CIDRs allowed on port 22. Default `["0.0.0.0/0"]` (open) — **strongly** recommended to lock down when using password auth |
| `relax_api_key` | Relax.ai API key used as OpenClaw's model backend |
| `relax_model` | Relax.ai model id rendered into OpenClaw config as `relax/<relax_model>` (e.g. `"Kimi-K25"`) |
| `slack_bot_token` | Optional Slack `xoxb-…` token |
| `slack_app_token` | Optional Slack `xapp-…` token (required if the bot token is set) |

Two secrets are **auto-generated** by Terraform and exposed as sensitive outputs:
- `ssh_password` — Civo's initial password for the `civo` user (`terraform output -raw ssh_password`)
- `openclaw_gateway_token` — bearer token for the OpenClaw gateway (`terraform output -raw openclaw_gateway_token`)

## Using OpenClaw

Open the tunnel, then point your client at `http://localhost:18789`:

```bash
$(terraform output -raw gateway_tunnel_command)

# In another terminal:
export OPENCLAW_GATEWAY_TOKEN=$(terraform output -raw openclaw_gateway_token)
curl -H "Authorization: Bearer $OPENCLAW_GATEWAY_TOKEN" \
     http://localhost:18789/health
```

OpenClaw is configured to send completions to Relax.ai as provider `relax/<relax_model>`.

## Using DefenseClaw

DefenseClaw's CLI is installed under `/home/civo/.local/bin`. SSH in and run:

```bash
ssh civo@$(terraform output -raw instance_public_ip)
# (paste the password from `terraform output -raw ssh_password`)

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

- Instance has a public IP. The Civo firewall denies everything except SSH from `ssh_allowed_cidr` and outbound 80/443/53.
- OpenClaw (`18789`) and DefenseClaw (`8765`) listen on `127.0.0.1` only — never exposed publicly.
- **Password-based SSH is enabled** for the default `civo` user. Combined with `ssh_allowed_cidr = ["0.0.0.0/0"]` this is brute-force exposed. Either narrow the CIDR to your source IP or switch back to key-based auth before using this outside a demo.
- The gateway token is still required on OpenClaw's HTTP surface.
- The upstream installers (`openclaw.ai/install.sh`, `cisco-ai-defense/defenseclaw/main/scripts/install.sh`) are fetched from `main` — pin versions before using this anywhere near production.

## Teardown

```bash
terraform destroy
```

Removes the instance, firewall, and network. Nothing persists in Civo.
