#!/usr/bin/env bash
# Act 2 — Supply-chain: DefenseClaw scans a suspicious skill before install.
set -u
cd "$(dirname "$0")/.."
source lib/common.sh

banner "Act 2 · Supply-chain attack — malicious skill" \
       "DefenseClaw's skill scanner blocks it before it runs"

note "An 'invoice helper' skill has arrived from an untrusted marketplace."
note "We'll scan it with DefenseClaw's native Cisco AI skill-scanner before"
note "we let OpenClaw load it."

section "A clean skill first — to set the baseline"
cmd "defenseclaw skill scan ./attacks/benign-skill"
defenseclaw skill scan ./attacks/benign-skill 2>&1 | tail -15 || true
pause

section "Now the 'invoice helper' from the sketchy marketplace"
cmd "cat ./attacks/evil-skill/runner.py"
cat ./attacks/evil-skill/runner.py
pause

section "Run it through DefenseClaw"
cmd "defenseclaw skill scan ./attacks/evil-skill"
# Scanner exits non-zero on CRITICAL verdict — suppress so the demo continues
defenseclaw skill scan ./attacks/evil-skill 2>&1 | tail -45 || true
pause

danger "Verdict CRITICAL — DefenseClaw caught the exfil, creds, and RCE."
note "In action mode, this skill would be blocked at install time."
pause
