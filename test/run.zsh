#!/bin/zsh

set -u

ROOT_DIR="${0:A:h:h}"
HELPER="$ROOT_DIR/bin/codex-open-folder.zsh"
FAILURES=0

fail() {
  print -r -- "not ok - $1"
  FAILURES=$((FAILURES + 1))
}

pass() {
  print -r -- "ok - $1"
}

assert_eq() {
  local name="$1"
  local actual="$2"
  local expected="$3"

  if [[ "$actual" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name"
    print -r -- "  expected: $expected"
    print -r -- "  actual:   $actual"
  fi
}

assert_file_contains() {
  local name="$1"
  local file="$2"
  local expected="$3"

  if [[ -f "$file" ]] && /usr/bin/grep -Fq "$expected" "$file"; then
    pass "$name"
  else
    fail "$name"
    print -r -- "  expected $file to contain: $expected"
  fi
}

make_case() {
  local name="$1"
  local base="/private/tmp/open-in-codex-zsh-tests/$$/$name"
  mkdir -p "$base/home/.codex" "$base/config" "$base/project"
  print -r -- "$base"
}

create_threads_db() {
  local db="$1"
  /usr/bin/sqlite3 "$db" <<'SQL'
CREATE TABLE threads (
  id TEXT PRIMARY KEY,
  cwd TEXT NOT NULL,
  archived INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL,
  updated_at_ms INTEGER
);
SQL
}

write_global_state() {
  local file="$1"
  local folder="$2"
  mkdir -p "${file:h}"
  printf '{"electron-saved-workspace-roots":["%s"]}\n' "$folder" > "$file"
}

run_helper() {
  local base="$1"
  local folder="$2"
  local prompt_response="${3:-Cancel}"
  local fallback_response="${4:-Open Codex}"

  env \
    HOME="$base/home" \
    CODEX_HOME="$base/home/.codex" \
    OPEN_IN_CODEX_CONFIG_HOME="$base/config" \
    OPEN_IN_CODEX_TEST_MODE=1 \
    OPEN_IN_CODEX_PROMPT_RESPONSE="$prompt_response" \
    OPEN_IN_CODEX_FALLBACK_RESPONSE="$fallback_response" \
    /bin/zsh "$HELPER" "$folder"
}

test_exact_thread_wins() {
  local base
  base="$(make_case exact-thread)"
  local folder="$base/project"
  local db="$base/home/.codex/state_5.sqlite"
  create_threads_db "$db"
  /usr/bin/sqlite3 "$db" "INSERT INTO threads (id,cwd,archived,updated_at,updated_at_ms) VALUES ('older','$folder',0,1,1000),('newer','$folder',0,2,2000),('archived','$folder',1,3,3000);"
  write_global_state "$base/home/.codex/.codex-global-state.json" "$folder"

  local output
  output="$(run_helper "$base" "$folder")"

  assert_eq "opens latest exact folder thread first" "$output" $'OPEN_URL\tcodex://threads/newer'
}

test_saved_project_opens_folder() {
  local base
  base="$(make_case saved-project)"
  local folder="$base/project"
  local db="$base/home/.codex/state_5.sqlite"
  create_threads_db "$db"
  write_global_state "$base/home/.codex/.codex-global-state.json" "$folder"

  local output
  output="$(run_helper "$base" "$folder")"

  assert_eq "opens saved project folder" "$output" $'OPEN_FOLDER\t'"$folder"
}

test_unknown_folder_prompt_open_project() {
  local base
  base="$(make_case prompt-open-project)"
  local folder="$base/project"
  local db="$base/home/.codex/state_5.sqlite"
  create_threads_db "$db"

  local output
  output="$(run_helper "$base" "$folder" "Open Project")"

  assert_eq "unknown folder can open as project" "$output" $'OPEN_FOLDER\t'"$folder"
}

test_unknown_folder_prompt_open_codex() {
  local base
  base="$(make_case prompt-open-codex)"
  local folder="$base/project"
  local db="$base/home/.codex/state_5.sqlite"
  create_threads_db "$db"

  local output
  output="$(run_helper "$base" "$folder" "Open Codex")"

  assert_eq "unknown folder can open Codex only" "$output" "OPEN_CODEX"
}

test_incompatible_state_enters_fallback() {
  local base
  base="$(make_case incompatible-state)"
  local folder="$base/project"
  /usr/bin/sqlite3 "$base/home/.codex/state_5.sqlite" "CREATE TABLE other (id TEXT);"

  local output
  output="$(run_helper "$base" "$folder")"

  assert_eq "incompatible state opens Codex only" "$output" $'FALLBACK_DIALOG\tOpen Codex\nOPEN_CODEX'
  assert_file_contains "fallback mode is saved" "$base/config/fallback-mode" "open-codex-only"

  local second_output
  second_output="$(run_helper "$base" "$folder")"
  assert_eq "saved fallback skips future state inspection" "$second_output" "OPEN_CODEX"
}

test_non_folder_rejected() {
  local base
  base="$(make_case non-folder)"
  local file="$base/file.txt"
  local db="$base/home/.codex/state_5.sqlite"
  create_threads_db "$db"
  print -r -- "not a folder" > "$file"

  local output
  output="$(run_helper "$base" "$file")"

  assert_eq "non-folder selection shows error" "$output" $'INFO_DIALOG\tOpen in Codex expects a folder, not a file: '"$file"
}

test_exact_thread_wins
test_saved_project_opens_folder
test_unknown_folder_prompt_open_project
test_unknown_folder_prompt_open_codex
test_incompatible_state_enters_fallback
test_non_folder_rejected

if (( FAILURES > 0 )); then
  print -r -- "$FAILURES test(s) failed"
  exit 1
fi

print -r -- "all tests passed"
