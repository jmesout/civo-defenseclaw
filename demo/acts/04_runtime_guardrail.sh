#!/usr/bin/env bash
# Act 4 — Runtime: every LLM call is routed through DefenseClaw's guardrail.
set -u
cd "$(dirname "$0")/.."
source lib/common.sh

banner "Act 4 · Runtime inspection — every LLM call proxied" \
       "DefenseClaw's guardrail sits between OpenClaw and Relax.ai"

note "Scanners stop bad code before it runs. The guardrail goes further:"
note "it inspects every prompt + completion at runtime, looking for"
note "prompt-injection, secrets, PII, and exfiltration patterns."

section "Gateway sidecar health"
cmd "defenseclaw-gateway status | grep -E 'Gateway|Guardrail'"
defenseclaw-gateway status 2>&1 | grep -E 'Gateway|Guardrail' || true
pause

section "OpenClaw routes via provider 'defenseclaw' (port 18889)"
cmd "jq '.models.providers | keys' ~/.openclaw/openclaw.json"
jq '.models.providers | keys' ~/.openclaw/openclaw.json || true
pause

section "Ask OpenClaw a normal question — live through the proxy"
cmd "openclaw capability model run --gateway --model relax/Kimi-K25 --prompt '…'"
openclaw capability model run --gateway --model relax/Kimi-K25 \
  --prompt "In 20 words, what does DefenseClaw do?" --json 2>&1 \
  | python3 -c "import json,sys
try:
    d=json.loads(sys.stdin.read())
    print(d['outputs'][0]['text'])
except Exception as e:
    print('error:', e)" || true
pause

section "Proof the guardrail saw it — live events in the proxy log"
cmd "tail -n 200 ~/.defenseclaw/gateway.log | grep bifrost | tail -10"
tail -n 200 ~/.defenseclaw/gateway.log 2>/dev/null | grep bifrost | tail -10 || true
pause

note "Every bifrost line is a DefenseClaw interception — prompts, responses,"
note "tool calls, all inspected before they leave the box."
pause
