#!/bin/zsh

set -u

UPDATE_URL="https://github.com/PatrickJS/codex-open-folder"
FALLBACK_VALUE="open-codex-only"

is_test_mode() {
  [[ "${OPEN_IN_CODEX_TEST_MODE:-}" == "1" ]]
}

emit_test() {
  print -r -- "$1"
}

config_home() {
  if [[ -n "${OPEN_IN_CODEX_CONFIG_HOME:-}" ]]; then
    print -r -- "$OPEN_IN_CODEX_CONFIG_HOME"
  elif [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
    print -r -- "$XDG_CONFIG_HOME/open-in-codex"
  else
    print -r -- "$HOME/.config/open-in-codex"
  fi
}

fallback_file() {
  print -r -- "$(config_home)/fallback-mode"
}

codex_home() {
  print -r -- "${CODEX_HOME:-$HOME/.codex}"
}

state_db_path() {
  print -r -- "${CODEX_STATE_DB:-$(codex_home)/state_5.sqlite}"
}

global_state_path() {
  print -r -- "${CODEX_GLOBAL_STATE:-$(codex_home)/.codex-global-state.json}"
}

show_info_dialog() {
  local message="$1"
  if is_test_mode; then
    emit_test $'INFO_DIALOG\t'"$message"
    return 0
  fi

  /usr/bin/osascript - "$message" <<'APPLESCRIPT' >/dev/null 2>&1
on run argv
  display dialog (item 1 of argv) buttons {"OK"} default button "OK" with icon caution
end run
APPLESCRIPT
}

open_url() {
  local url="$1"
  if is_test_mode; then
    emit_test $'OPEN_URL\t'"$url"
    return 0
  fi

  /usr/bin/open "$url" >/dev/null 2>&1
}

open_codex() {
  if is_test_mode; then
    emit_test "OPEN_CODEX"
    return 0
  fi

  /usr/bin/open -a "Codex" >/dev/null 2>&1
}

open_folder_in_codex() {
  local folder="$1"
  if is_test_mode; then
    emit_test $'OPEN_FOLDER\t'"$folder"
    return 0
  fi

  /usr/bin/open -a "Codex" "$folder" >/dev/null 2>&1
}

folder_absolute_path() {
  local input="$1"
  if [[ "$input" == /* ]]; then
    print -r -- "$input"
  else
    print -r -- "$PWD/$input"
  fi
}

folder_real_path() {
  local folder="$1"
  local physical
  physical="$(cd -P "$folder" 2>/dev/null && pwd)"
  if [[ -n "$physical" ]]; then
    print -r -- "$physical"
  else
    print -r -- "$folder"
  fi
}

unique_paths() {
  local -a seen
  local path
  seen=()

  for path in "$@"; do
    [[ -z "$path" ]] && continue
    if (( ${seen[(Ie)$path]} == 0 )); then
      seen+=("$path")
      print -r -- "$path"
    fi
  done
}

sql_quote() {
  local value="$1"
  local escaped
  escaped="$(printf "%s" "$value" | /usr/bin/sed "s/'/''/g")"
  printf "'%s'" "$escaped"
}

sqlite_has_column() {
  local db="$1"
  local column="$2"
  local rows line name

  rows="$(/usr/bin/sqlite3 "$db" "PRAGMA table_info(threads);" 2>/dev/null)" || return 1
  while IFS='|' read -r _ name _; do
    [[ "$name" == "$column" ]] && return 0
  done <<< "$rows"

  return 1
}

state_contract_status() {
  local db
  db="$(state_db_path)"

  [[ -x /usr/bin/sqlite3 ]] || {
    print -r -- "sqlite3 is unavailable"
    return 1
  }

  [[ -f "$db" ]] || {
    print -r -- "Codex state database was not found at $db"
    return 1
  }

  /usr/bin/sqlite3 "$db" "SELECT 1 FROM sqlite_master WHERE type='table' AND name='threads' LIMIT 1;" 2>/dev/null | /usr/bin/grep -qx "1" || {
    print -r -- "Codex state database does not contain the expected threads table"
    return 1
  }

  local required
  for required in id cwd archived updated_at; do
    sqlite_has_column "$db" "$required" || {
      print -r -- "Codex threads table is missing expected column: $required"
      return 1
    }
  done

  print -r -- "ok"
  return 0
}

order_expression() {
  local db
  db="$(state_db_path)"
  if sqlite_has_column "$db" "updated_at_ms"; then
    print -r -- "COALESCE(updated_at_ms, updated_at * 1000)"
  else
    print -r -- "updated_at"
  fi
}

lookup_latest_thread_id() {
  local -a candidates
  candidates=("$@")
  local db order_expr quoted_parts path sql result
  db="$(state_db_path)"
  order_expr="$(order_expression)"
  quoted_parts=()

  for path in "${candidates[@]}"; do
    quoted_parts+=("$(sql_quote "$path")")
  done

  sql="SELECT id FROM threads WHERE archived=0 AND cwd IN (${(j:,:)quoted_parts}) ORDER BY $order_expr DESC, updated_at DESC LIMIT 1;"
  result="$(/usr/bin/sqlite3 "$db" "$sql" 2>/dev/null)" || return 1
  result="${result%%$'\n'*}"

  [[ -n "$result" ]] && print -r -- "$result"
}

global_state_status() {
  local file
  file="$(global_state_path)"
  [[ -f "$file" ]] || return 0

  /usr/bin/plutil -type "electron-saved-workspace-roots" "$file" 2>/dev/null | /usr/bin/grep -qx "array" || {
    print -r -- "Codex global state exists but electron-saved-workspace-roots is not an array"
    return 1
  }

  return 0
}

is_saved_project() {
  local -a candidates
  candidates=("$@")
  local file count i root candidate
  file="$(global_state_path)"
  [[ -f "$file" ]] || return 1

  count="$(/usr/bin/plutil -extract "electron-saved-workspace-roots" raw -o - "$file" 2>/dev/null)" || return 1
  [[ "$count" == <-> ]] || return 1

  for (( i = 0; i < count; i++ )); do
    root="$(/usr/bin/plutil -extract "electron-saved-workspace-roots.$i" raw -o - "$file" 2>/dev/null)" || continue
    for candidate in "${candidates[@]}"; do
      [[ "$root" == "$candidate" ]] && return 0
    done
  done

  return 1
}

save_fallback_mode() {
  local file
  file="$(fallback_file)"
  mkdir -p "${file:h}"
  print -r -- "$FALLBACK_VALUE" > "$file"
}

fallback_enabled() {
  local file
  file="$(fallback_file)"
  [[ -f "$file" ]] && /usr/bin/grep -Fqx "$FALLBACK_VALUE" "$file"
}

choose_fallback_action() {
  local reason="$1"
  if is_test_mode; then
    print -r -- "${OPEN_IN_CODEX_FALLBACK_RESPONSE:-Open Codex}"
    return 0
  fi

  /usr/bin/osascript - "$reason" "$UPDATE_URL" <<'APPLESCRIPT' 2>/dev/null
on run argv
  set reasonText to item 1 of argv
  set updateUrl to item 2 of argv
  set promptText to "Open in Codex needs an update because Codex local state changed." & return & return & reasonText & return & return & "Until the tool is updated, this Quick Action will only open Codex."
  return button returned of (display dialog promptText buttons {"Cancel", "Open Updates", "Open Codex"} default button "Open Codex" with icon caution)
end run
APPLESCRIPT
}

handle_incompatible_state() {
  local reason="$1"
  save_fallback_mode

  local action
  action="$(choose_fallback_action "$reason")"
  if is_test_mode; then
    emit_test $'FALLBACK_DIALOG\t'"$action"
  fi
  case "$action" in
    "Open Updates")
      open_url "$UPDATE_URL"
      ;;
    "Open Codex"|"")
      open_codex
      ;;
    *)
      return 0
      ;;
  esac
}

choose_new_folder_action() {
  local folder="$1"
  if is_test_mode; then
    print -r -- "${OPEN_IN_CODEX_PROMPT_RESPONSE:-Cancel}"
    return 0
  fi

  /usr/bin/osascript - "$folder" <<'APPLESCRIPT' 2>/dev/null
on run argv
  set folderPath to item 1 of argv
  set promptText to "No existing Codex chat or saved project was found for:" & return & return & folderPath & return & return & "Open this folder in Codex as a project, or just open Codex?"
  return button returned of (display dialog promptText buttons {"Cancel", "Open Codex", "Open Project"} default button "Open Project" with icon note)
end run
APPLESCRIPT
}

handle_folder() {
  local input="$1"
  local folder
  folder="$(folder_absolute_path "$input")"

  if [[ ! -e "$folder" ]]; then
    show_info_dialog "Path does not exist: $folder"
    return 1
  fi

  if [[ ! -d "$folder" ]]; then
    show_info_dialog "Open in Codex expects a folder, not a file: $folder"
    return 1
  fi

  if fallback_enabled; then
    open_codex
    return 0
  fi

  local contract
  contract="$(state_contract_status)" || {
    handle_incompatible_state "$contract"
    return 0
  }

  local global_status
  global_status="$(global_state_status)" || {
    handle_incompatible_state "$global_status"
    return 0
  }

  local real_folder thread_id choice
  real_folder="$(folder_real_path "$folder")"
  local -a candidates
  candidates=("${(@f)$(unique_paths "$folder" "$real_folder")}")

  thread_id="$(lookup_latest_thread_id "${candidates[@]}")"
  if [[ -n "$thread_id" ]]; then
    open_url "codex://threads/$thread_id"
    return 0
  fi

  if is_saved_project "${candidates[@]}"; then
    open_folder_in_codex "$folder"
    return 0
  fi

  choice="$(choose_new_folder_action "$folder")"
  case "$choice" in
    "Open Project")
      open_folder_in_codex "$folder"
      ;;
    "Open Codex")
      open_codex
      ;;
    *)
      return 0
      ;;
  esac
}

main() {
  if (( $# == 0 )); then
    show_info_dialog "Select a folder in Finder, then choose Open in Codex."
    return 1
  fi

  local exit_status=0
  local input
  for input in "$@"; do
    handle_folder "$input" || exit_status=1
  done

  return "$exit_status"
}

main "$@"
