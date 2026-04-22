#!/usr/bin/env bash
# Act 5 — Forensics: DefenseClaw's audit trail + alerts.
set -u
cd "$(dirname "$0")/.."
source lib/common.sh

banner "Act 5 · Forensics — audit trail + alerts" \
       "Every scan + decision is recorded for review"

note "Everything DefenseClaw does lands in a local SQLite audit store and"
note "is surfaced through the CLI. Wire in Splunk or OTLP and you have"
note "enterprise-grade observability."

section "Recent alerts (plain table — the TUI is also available without --no-tui)"
cmd "defenseclaw alerts --no-tui -n 15"
defenseclaw alerts --no-tui -n 15 2>&1 | tail -25 || true
pause

section "The audit store (SQLite — ships with every install)"
cmd "sqlite3 ~/.defenseclaw/audit.db '.tables'"
sqlite3 ~/.defenseclaw/audit.db '.tables' 2>/dev/null || note "(sqlite3 not installed — audit.db still on disk)"
cmd "ls -lh ~/.defenseclaw/audit.db"
ls -lh ~/.defenseclaw/audit.db 2>/dev/null || true
pause

section "Enterprise integrations available out of the box"
note "  • Splunk HEC  — defenseclaw setup splunk"
note "  • OTLP         — ship logs/spans/metrics to Grafana, Jaeger, Splunk Obs"
note "  • Webhooks     — Slack, PagerDuty, Webex, generic HTTP"
note "  • Policy as code — OPA/Rego bundles in ~/.defenseclaw/policies"
pause
