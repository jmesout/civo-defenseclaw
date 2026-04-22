# shellcheck shell=bash
# Shared helpers used by every demo act.
# Colours, banners, pauses. Source this from each act.

BOLD=$'\033[1m'
DIM=$'\033[2m'
RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
BLUE=$'\033[34m'
MAGENTA=$'\033[35m'
CYAN=$'\033[36m'
RESET=$'\033[0m'

banner() {
  local title="$1"
  local subtitle="${2:-}"
  printf '\n'
  printf '%s%s══════════════════════════════════════════════════════════════════════%s\n' "$BOLD" "$CYAN" "$RESET"
  printf '%s%s  %s%s\n' "$BOLD" "$CYAN" "$title" "$RESET"
  [ -n "$subtitle" ] && printf '%s  %s%s\n' "$DIM" "$subtitle" "$RESET"
  printf '%s%s══════════════════════════════════════════════════════════════════════%s\n' "$BOLD" "$CYAN" "$RESET"
  printf '\n'
}

section() {
  printf '\n%s%s▸ %s%s\n' "$BOLD" "$YELLOW" "$1" "$RESET"
}

cmd() {
  printf '%s%s$ %s%s\n' "$BOLD" "$GREEN" "$1" "$RESET"
}

note() {
  printf '%s   %s%s\n' "$DIM" "$1" "$RESET"
}

success() {
  printf '%s%s✓ %s%s\n' "$BOLD" "$GREEN" "$1" "$RESET"
}

danger() {
  printf '%s%s✗ %s%s\n' "$BOLD" "$RED" "$1" "$RESET"
}

pause() {
  printf '\n%s%s   [press ENTER to continue]%s ' "$DIM" "$YELLOW" "$RESET"
  read -r _
}
