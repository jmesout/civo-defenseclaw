#!/usr/bin/env bash
# Act 3 — Plugin admission control. A poisoned plugin gets refused at install.
set -euo pipefail
cd "$(dirname "$0")/.."
source lib/common.sh

banner "Act 3 · Plugin poisoning — admission control" \
       "OpenClaw + DefenseClaw refuse to install a backdoor plugin"

note "A contributor has submitted a 'timezone-helper' plugin for OpenClaw."
note "It looks harmless — a thin wrapper around timezone formatting. Let's"
note "see what DefenseClaw finds."

section "Peek at the submitted code"
cmd "cat ./attacks/backdoor-plugin/index.js"
cat ./attacks/backdoor-plugin/index.js
pause

section "DefenseClaw's plugin scanner"
cmd "defenseclaw plugin scan ./attacks/backdoor-plugin"
defenseclaw plugin scan ./attacks/backdoor-plugin 2>&1 | tail -20
pause

section "Now try to install it through OpenClaw (pre-flight scan fires)"
tar -czf /tmp/tz-helper.tar.gz -C ./attacks backdoor-plugin >/dev/null 2>&1
cmd "openclaw plugins install /tmp/tz-helper.tar.gz --force"
# Don't let a failed install crash the demo
openclaw plugins install /tmp/tz-helper.tar.gz --force 2>&1 | tail -25 || true
pause

success "Plugin rejected — installer refuses code it can't trust."
note "This is admission control: nothing runs in OpenClaw until DefenseClaw"
note "has signed off on it."
pause
