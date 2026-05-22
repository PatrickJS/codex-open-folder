#!/bin/zsh

set -u

INSTALL_HOME="${OPEN_IN_CODEX_INSTALL_HOME:-$HOME}"
DRY_RUN=0
NO_REFRESH=0

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=1
      ;;
    --no-refresh)
      NO_REFRESH=1
      ;;
    *)
      print -r -- "Unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

HELPER_TARGET="$INSTALL_HOME/.codex/bin/codex-open-folder.zsh"
OLD_NODE_HELPER="$INSTALL_HOME/.codex/bin/codex-open-folder.mjs"
WORKFLOW_DIR="$INSTALL_HOME/Library/Services/Open in Codex.workflow"
CONFIG_HOME="${OPEN_IN_CODEX_CONFIG_HOME:-${XDG_CONFIG_HOME:-$INSTALL_HOME/.config}/open-in-codex}"
FALLBACK_FILE="$CONFIG_HOME/fallback-mode"

run_or_echo() {
  if (( DRY_RUN )); then
    print -r -- "[dry-run] $*"
  else
    "$@"
  fi
}

if [[ -e "$WORKFLOW_DIR" ]]; then
  run_or_echo rm -rf "$WORKFLOW_DIR"
fi

if [[ -f "$HELPER_TARGET" ]]; then
  run_or_echo rm -f "$HELPER_TARGET"
fi

if [[ -f "$OLD_NODE_HELPER" ]]; then
  run_or_echo rm -f "$OLD_NODE_HELPER"
fi

if [[ -f "$FALLBACK_FILE" ]]; then
  run_or_echo rm -f "$FALLBACK_FILE"
fi

if (( ! DRY_RUN )); then
  rmdir "$CONFIG_HOME" >/dev/null 2>&1 || true
fi

if (( ! DRY_RUN && ! NO_REFRESH )); then
  /usr/bin/touch "$INSTALL_HOME/Library/Services" 2>/dev/null || true
  /System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true
  /System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true
fi

print -r -- "Removed Open in Codex Finder Quick Action files owned by this project."
