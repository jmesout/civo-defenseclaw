# civo-defenseclaw · Demo

Five-act walkthrough of Cisco DefenseClaw's governance for agentic AI,
running against OpenClaw + Relax.ai on Civo.

```
  Act 1 · Know the stack         posture + AI Bill of Materials
  Act 2 · Supply-chain attack    malicious skill blocked pre-install
  Act 3 · Plugin poisoning       OpenClaw refuses a backdoor plugin
  Act 4 · Runtime guardrail      every LLM call inspected live
  Act 5 · Forensics              audit trail + alerts + integrations
```

Total: ~5 minutes plus whatever narration you layer on top.

## Run it

From your laptop, with a live `terraform apply` in the repo root:

```bash
./demo-remote.sh
```

That uploads `demo/` to the Civo instance, opens an interactive SSH
session, and kicks off `run.sh`. Each act pauses between sections — press
ENTER when you're ready to continue.

## Narration cheat sheet

### Act 1 · Know the stack

> "DefenseClaw is Cisco's governance layer for agentic AI. Before
> anything can be defended, it has to be *known*. So every DefenseClaw
> install starts with an inventory view — every agent, every skill,
> every plugin, every model, in one table."

Commands the audience sees:
- `defenseclaw-gateway status` — sidecar health
- `defenseclaw aibom` — AI Bill of Materials

### Act 2 · Supply-chain attack

> "An agent's biggest attack surface isn't the model — it's everything
> it loads. Skills, plugins, MCP servers. DefenseClaw scans them with
> Cisco's own AI skill-scanner before they ever run."

Scan a clean skill first (passes). Then scan `invoice-helper`, a
deliberately-malicious skill with hardcoded AWS keys, `eval()`, `curl |
bash`, and `/etc/shadow` reads. Verdict: **CRITICAL (2 critical, 2 high,
1 medium)** — with file+line locations for every finding.

### Act 3 · Plugin poisoning

> "DefenseClaw doesn't just report — it blocks. Watch what happens when
> we try to install a plugin that contains a backdoor."

Scan the `timezone-helper` plugin (which exfiltrates env + runs remote
code). Then try `openclaw plugins install`. OpenClaw refuses — this is
the **admission gate** from DefenseClaw's protection layers.

### Act 4 · Runtime guardrail

> "Scanners catch code before it runs. But we still have to trust the
> prompts, tool calls, and completions at runtime. DefenseClaw proxies
> every LLM call through its Go sidecar for inline inspection."

Show `Guardrail: RUNNING`. Show OpenClaw's config with the `defenseclaw`
provider routing via `127.0.0.1:18889`. Fire a real LLM call. Show the
bifrost events in `~/.defenseclaw/gateway.log` proving every token
passed through DefenseClaw.

### Act 5 · Forensics

> "Detection without a paper trail is useless. Everything DefenseClaw
> does — every scan, every block, every policy decision — lands in a
> SQLite audit store and is pushable to Splunk, OTLP, or a webhook."

Show recent alerts. Show the audit DB on disk. List the enterprise
integrations that ship out of the box.

## Reset between runs

The demo is idempotent but the alerts table grows. To wipe:

```bash
ssh civo@$(terraform output -raw instance_public_ip)
defenseclaw init --skip-install  # rotates audit.db
```
