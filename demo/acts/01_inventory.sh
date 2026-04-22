#!/usr/bin/env bash
# Act 1 — Posture check. DefenseClaw's sidecar health + built-in policies.
set -euo pipefail
cd "$(dirname "$0")/.."
source lib/common.sh
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

banner "Act 1 · Know the stack you're defending" \
       "Cisco DefenseClaw — posture, health, and policy at a glance"

note "Before you can govern agents, you have to see them. DefenseClaw"
note "ships a live health + config view for the whole stack."

section "Sidecar health — gateway, watcher, API, guardrail"
cmd "defenseclaw-gateway status"
defenseclaw-gateway status | sed '/^$/d' | head -20
pause

section "DefenseClaw doctor — config, DB, scanners, services"
cmd "defenseclaw doctor"
defenseclaw doctor 2>&1 | sed '/^$/d' | head -20
pause

section "Built-in security policies (OPA/Rego-backed)"
cmd "defenseclaw policy list"
defenseclaw policy list 2>&1 | head -20
pause

note "Four policies ship out of the box — from permissive (dev) to"
note "strict (high-risk production). Active policy right now: default."
pause
