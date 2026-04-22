#!/usr/bin/env bash
# Master demo runner — orchestrates the 5 acts in order, with pauses.
#
# Run this ON THE CIVO INSTANCE (the demo/ folder gets uploaded there by
# ../demo-remote.sh). Relies on defenseclaw/openclaw/jq being on PATH.
set -euo pipefail

cd "$(dirname "$0")"
source lib/common.sh

# Make sure the CLIs we use are on PATH regardless of how the shell was
# invoked.
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

title() {
  clear
  printf '\n'
  printf '%s%s       ██████╗██╗███████╗ ██████╗ ██████╗%s\n' "$BOLD" "$CYAN" "$RESET"
  printf '%s%s      ██╔════╝██║██╔════╝██╔════╝██╔═══██╗%s\n' "$BOLD" "$CYAN" "$RESET"
  printf '%s%s      ██║     ██║███████╗██║     ██║   ██║%s\n' "$BOLD" "$CYAN" "$RESET"
  printf '%s%s      ██║     ██║╚════██║██║     ██║   ██║%s\n' "$BOLD" "$CYAN" "$RESET"
  printf '%s%s      ╚██████╗██║███████║╚██████╗╚██████╔╝%s\n' "$BOLD" "$CYAN" "$RESET"
  printf '%s%s       ╚═════╝╚═╝╚══════╝ ╚═════╝ ╚═════╝%s\n' "$BOLD" "$CYAN" "$RESET"
  printf '\n'
  printf '%s%s       DefenseClaw · Governance for agentic AI%s\n' "$BOLD" "$CYAN" "$RESET"
  printf '%s          Relax.ai-backed OpenClaw, deployed on Civo%s\n' "$DIM" "$RESET"
  printf '\n'
}

ACTS=(
  acts/01_inventory.sh
  acts/02_skill_scan.sh
  acts/03_plugin_admission.sh
  acts/04_runtime_guardrail.sh
  acts/05_forensics.sh
)

title
pause

for act in "${ACTS[@]}"; do
  bash "$act"
done

banner "Demo complete" "Cisco DefenseClaw — posture, prevention, runtime, forensics"
printf '%s  Five protection layers, one install.%s\n' "$BOLD" "$RESET"
printf '%s  Source: https://github.com/cisco-ai-defense/defenseclaw%s\n' "$DIM" "$RESET"
printf '\n'
