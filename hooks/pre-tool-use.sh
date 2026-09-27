#!/usr/bin/env bash
#
# doc-first edit gate
#
# An AI tool's "before tool" hook runs this script right before a file edit.
# Code edits are allowed only in sessions where the doc-first workflow
# (document pre-reflection + user confirmation) has been completed.
#
# Usage: pre-tool-use.sh [--tool=<claude|gemini|copilot|codex|opencode>]
#   The hook payload arrives on stdin. --tool selects how the payload is read
#   and how a denial is reported; it defaults to claude.
#
# Approval signal = existence of a sentinel file.
#   - Path: ${TMPDIR:-/tmp}/doc-first-approved.<tool>.<session_id>
#   - The AI creates it with `touch` after completing the doc-first procedure
#   - The OS cleans it up when the session's temp dir is purged (no manual cleanup)
#
# Identification marker: # doc-first-gate
#   (install.sh finds the hook entry by this marker for idempotent installation)

set -euo pipefail

VALID_TOOLS="claude gemini copilot codex opencode"
TOOL="claude"

for arg in "$@"; do
  case "$arg" in
    --tool=*) TOOL="${arg#--tool=}" ;;
  esac
done

# --- jq dependency ---------------------------------------------------------

if ! command -v jq >/dev/null 2>&1; then
  # Without jq the gate is disabled (safe fallback). Only a notice goes to stderr.
  echo "[doc-first-gate] jq not found, skipping gate" >&2
  exit 0
fi

# --- Tool argument ---------------------------------------------------------

case " ${VALID_TOOLS} " in
  *" ${TOOL} "*) ;;
  *)
    # A wrong registration, not a wrong edit: disable the gate instead of blocking.
    echo "[doc-first-gate] unknown tool '${TOOL}', skipping gate" >&2
    exit 0
    ;;
esac

# --- parse_payload [F-03] --------------------------------------------------
#
# Reads the hook JSON on stdin and normalizes it to:
#   IS_EDIT_TOOL  1 when the call is a file-editing tool of this AI tool
#   FILES         absolute paths of the files the call would change (one per line)
#   SESSION_ID    session identifier for the sentinel name
# Everything that differs between tools lives here.

# Paths named by "*** Add File:", "*** Update File:", "*** Delete File:" lines
# of an apply_patch body. Shared by Copilot, Codex and OpenCode.
JQ_PATCH_PATHS='
  def patch_paths:
    [ split("\n")[]
      | capture("^\\*\\*\\* (Add|Update|Delete) File: (?<path>.+)$")
      | .path | sub("^\\s+"; "") | sub("\\s+$"; "") ];
'

payload_filter_for_tool() {
  case "$1" in
    claude)
      echo '{
        edit: (.tool_name | IN("Write", "Edit")),
        paths: [ .tool_input.file_path // empty ],
        session: (.session_id // ""),
        cwd: (.cwd // "")
      }'
      ;;
    gemini)
      echo '{
        edit: (.tool_name | IN("write_file", "replace")),
        paths: [ .tool_input.file_path // empty ],
        session: (.session_id // ""),
        cwd: (.cwd // "")
      }'
      ;;
    copilot)
      # toolArgs field names are not documented: try the usual path keys, and
      # for apply_patch scan every string value for patch headers.
      echo '(.toolName // "") as $tool
      | {
        edit: ($tool | IN("create", "edit", "str_replace_editor", "apply_patch")),
        paths: (if $tool == "apply_patch"
                then ([ .toolArgs | .. | strings ] | join("\n") | patch_paths)
                else [ .toolArgs.path // .toolArgs.file_path // .toolArgs.filePath // empty ]
                end),
        session: (.sessionId // ""),
        cwd: (.cwd // "")
      }'
      ;;
    codex)
      echo '{
        edit: (.tool_name == "apply_patch"),
        paths: ((.tool_input.command // "") | patch_paths),
        session: (.session_id // ""),
        cwd: (.cwd // "")
      }'
      ;;
    opencode)
      # Payload built by opencode-plugin.js: {tool, sessionID, args}
      echo '(.tool // "") as $tool
      | {
        edit: ($tool | IN("write", "edit", "apply_patch")),
        paths: (if $tool == "apply_patch"
                then ((.args.patchText // "") | patch_paths)
                else [ .args.filePath // empty ]
                end),
        session: (.sessionID // ""),
        cwd: ""
      }'
      ;;
  esac
}

parse_payload() {
  local tool="$1" input="$2"
  local filter parsed base_dir path

  filter="${JQ_PATCH_PATHS} $(payload_filter_for_tool "$tool")"
  parsed="$(printf '%s' "$input" | jq -c "$filter")"

  if [[ "$(printf '%s' "$parsed" | jq -r '.edit')" == "true" ]]; then
    IS_EDIT_TOOL=1
  else
    IS_EDIT_TOOL=0
  fi

  SESSION_ID="$(printf '%s' "$parsed" | jq -r '.session')"
  [[ -n "$SESSION_ID" ]] || SESSION_ID="unknown"

  # Relative paths are resolved against the payload cwd, else this process cwd.
  base_dir="$(printf '%s' "$parsed" | jq -r '.cwd')"
  [[ -n "$base_dir" ]] || base_dir="$PWD"

  FILES=""
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    case "$path" in
      /*) ;;
      *)  path="${base_dir}/${path}" ;;
    esac
    FILES+="${path}"$'\n'
  done < <(printf '%s' "$parsed" | jq -r '.paths[]')
}

# --- find_doc_first_root [F-02] -------------------------------------------
#
# Walk up from $1 to / and print the first directory containing docs/src-notes/.

find_doc_first_root() {
  local dir="$1"
  while [[ -n "$dir" && "$dir" != "/" ]]; do
    if [[ -d "${dir}/docs/src-notes" ]]; then
      printf '%s' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

# --- is_gated_file [F-04] -------------------------------------------------
#
# True when the absolute path $1 is a source file of the project rooted at $2.
# Documentation, tests, config/build/lock files and files outside the project
# are not gated (matches the doc-first skill's own definition).

is_gated_file() {
  local abs_file="$1" project_root="$2"

  case "$abs_file" in
    "${project_root}"/*) ;;
    *) return 1 ;;
  esac

  # Documentation / test files
  case "$abs_file" in
    */docs/*|*.md|*.markdown|*.mdx) return 1 ;;
    *.test.[jt]s|*.test.[jt]sx|*.test.py|*.test.go) return 1 ;;
    *.spec.[jt]s|*.spec.[jt]sx|*.spec.py) return 1 ;;
    */tests/*|*/test/*|*/__tests__/*|*/spec/*) return 1 ;;
  esac

  # Project config / build / lock files
  case "$abs_file" in
    */package.json|*/package-lock.json|*/yarn.lock|*/pnpm-lock.yaml) return 1 ;;
    */tsconfig*.json|*/jsconfig.json) return 1 ;;
    */pyproject.toml|*/poetry.lock|*/Pipfile|*/Pipfile.lock|*/requirements*.txt) return 1 ;;
    */Cargo.toml|*/Cargo.lock|*/go.mod|*/go.sum) return 1 ;;
    */Gemfile|*/Gemfile.lock) return 1 ;;
    */Makefile|*/Dockerfile|*/.dockerignore) return 1 ;;
    */.gitignore|*/.gitattributes|*/.editorconfig|*/.env|*/.env.*) return 1 ;;
    *.yml|*.yaml|*.toml|*.lock) return 1 ;;
  esac

  return 0
}

# --- emit_deny [F-05] -----------------------------------------------------
#
# Print the denial in the JSON shape the calling tool understands.

emit_deny() {
  local tool="$1" reason="$2"
  case "$tool" in
    claude|codex)
      jq -n --arg reason "$reason" '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason: $reason
        }
      }'
      ;;
    gemini|opencode)
      jq -n --arg reason "$reason" '{ decision: "deny", reason: $reason }'
      ;;
    copilot)
      jq -n --arg reason "$reason" '{
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      }'
      ;;
  esac
}

# --- main [F-01] -----------------------------------------------------------

input="$(cat)"

IS_EDIT_TOOL=0
FILES=""
SESSION_ID="unknown"
parse_payload "$TOOL" "$input"

# Not a file-editing call (matcher-less hooks such as Copilot send every tool)
[[ "$IS_EDIT_TOOL" -eq 1 ]] || exit 0

# Nothing to judge (missing path field, empty patch)
[[ -n "$FILES" ]] || exit 0

# The hook runs in the session's cwd; not inside a doc-first project → pass
if ! project_root="$(find_doc_first_root "$PWD")"; then
  exit 0
fi

# Approved session → pass without looking at the files
sentinel="${TMPDIR:-/tmp}/doc-first-approved.${TOOL}.${SESSION_ID}"
if [[ -f "$sentinel" ]]; then
  exit 0
fi

# Any gated file in the call → deny
blocked=""
while IFS= read -r abs_file; do
  [[ -n "$abs_file" ]] || continue
  if is_gated_file "$abs_file" "$project_root"; then
    blocked+="  ${abs_file}"$'\n'
  fi
done <<< "$FILES"

[[ -n "$blocked" ]] || exit 0

# --- Deny + procedure guidance --------------------------------------------

read -r -d '' template <<'TEMPLATE' || true
doc-first workflow not completed — code modification blocked.

Complete the following steps in order, then retry:

1) Invoke the 'doc-first' skill
2) Pre-reflect the change scope and logic into docs/src-notes/
3) Show the document to the user and obtain approval
4) After approval, release the gate with:
   touch "__SENTINEL__"
5) Retry the edit

If a new scope becomes necessary after approval, follow §1.2 (Approved-Scope-Only):
halt immediately → update the document → re-confirm with the user → resume.

Blocked files:
__FILES__
TEMPLATE

reason="${template//__SENTINEL__/$sentinel}"
reason="${reason//__FILES__/${blocked%$'\n'}}"

emit_deny "$TOOL" "$reason"
