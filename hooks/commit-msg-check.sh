#!/usr/bin/env bash
#
# doc-first commit check (runs as a git commit-msg hook)
#
# Blocks a commit when a source file being committed has a src-notes
# document (per docs/src-notes/INDEX.md) that still contains change-review
# markup. Once the implementation is committed, the document must be the
# current source guide again (clean it with review-clean.sh).
#
# Usage (called by the commit-msg stub that install-git-hook.sh writes):
#   commit-msg-check.sh <commit-message-file>
#
# Exit codes: 0 allow (including warnings), 1 block the commit.
# A "[wip]" tag in the commit message (case-insensitive) turns a block into
# a warning. If the checker itself cannot run, the commit is allowed.

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEAN_SCRIPT="${SCRIPT_DIR}/review-clean.sh"
INDEX_PATH="docs/src-notes/INDEX.md"
DOCS_ROOT="docs/src-notes"
WIP_PATTERN='\[wip\]'
TAB=$'\t'
MESSAGE_FILE="${1:-}"

TEMP_FILES=()
cleanup() {
  local f
  for f in "${TEMP_FILES[@]}"; do
    rm -f "$f"
  done
}
trap cleanup EXIT

warn() { printf '[doc-first] %s\n' "$*" >&2; }

# ---- load_index [F-02] ----------------------------------------------------
# Prints "source<TAB>doc" lines from the INDEX.md tables.
load_index() {
  local line first_cell source doc
  local link_pattern='\]\(([^)]+\.md)\)'
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == \|* ]] || continue
    [[ "$line" =~ $link_pattern ]] || continue
    doc="${BASH_REMATCH[1]}"
    doc="${doc#./}"
    first_cell="${line#|}"
    first_cell="${first_cell%%|*}"
    source="$(printf '%s' "$first_cell" | tr -d '`' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [[ -n "$source" ]] || continue
    printf '%s\t%s/%s\n' "$source" "$DOCS_ROOT" "$doc"
  done < "$INDEX_PATH"
}

# ---- check_doc [F-03] -----------------------------------------------------
# Returns 0 clean, 1 markup in the committed version, 2 not checkable.
# Sets DOC_UNSTAGED_CLEAN=1 when the work tree copy is already clean.
check_doc() {
  local doc="$1" temp rc
  DOC_UNSTAGED_CLEAN=0
  temp="$(mktemp)" || return 2
  TEMP_FILES+=("$temp")

  if git cat-file -e ":${doc}" 2>/dev/null; then
    git show ":${doc}" > "$temp" 2>/dev/null || return 2
  elif [[ -f "$doc" ]]; then
    cp "$doc" "$temp" || return 2
  else
    return 0
  fi

  "$CLEAN_SCRIPT" --check "$temp" >/dev/null 2>&1
  rc=$?
  if [[ $rc -eq 1 && -f "$doc" ]]; then
    if "$CLEAN_SCRIPT" --check "$doc" >/dev/null 2>&1; then
      DOC_UNSTAGED_CLEAN=1
    fi
  fi
  return $rc
}

message_has_wip() {
  [[ -n "$MESSAGE_FILE" && -r "$MESSAGE_FILE" ]] || return 1
  grep -v '^#' "$MESSAGE_FILE" | grep -qi "$WIP_PATTERN"
}

print_block_message() {
  local entry source doc
  warn "Commit blocked: source is being committed while its doc still has change-review markup."
  echo >&2
  for entry in "${VIOLATIONS[@]}"; do
    source="${entry%%${TAB}*}"
    doc="${entry#*${TAB}}"
    printf '  %s  ->  %s\n' "$source" "$doc" >&2
  done
  echo >&2
  echo "The implementation is being committed, so refresh the doc to the current state:" >&2
  echo "  1) Confirm the implementation matches the doc" >&2
  for entry in "${VIOLATIONS[@]}"; do
    doc="${entry#*${TAB}}"
    echo "  2) Run: ${CLEAN_SCRIPT} ${doc}" >&2
  done
  echo "  3) git add the doc(s), then commit again" >&2
  if [[ ${#UNSTAGED_CLEAN[@]} -gt 0 ]]; then
    echo "Already cleaned but not staged (git add them): ${UNSTAGED_CLEAN[*]}" >&2
  fi
  echo "Work-in-progress commit? Add [wip] to the commit message." >&2
}

# ---- main [F-01] ----------------------------------------------------------

# (1) checker available
if [[ ! -x "$CLEAN_SCRIPT" ]]; then
  warn "commit check skipped: review-clean.sh unavailable (${CLEAN_SCRIPT} not found)"
  exit 0
fi
if ! command -v perl >/dev/null 2>&1; then
  warn "commit check skipped: review-clean.sh unavailable (perl not found)"
  exit 0
fi

# (2) doc-first project
if ! repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  warn "commit check skipped: not inside a git work tree"
  exit 0
fi
cd "$repo_root" || exit 0
[[ -f "$INDEX_PATH" ]] || exit 0

# (3) staged files and the source -> doc map
index_map="$(load_index)"
[[ -n "$index_map" ]] || exit 0

VIOLATIONS=()
UNSTAGED_CLEAN=()
while IFS= read -r -d '' staged; do
  # (4) only sources listed in INDEX.md
  mapping="$(printf '%s\n' "$index_map" | awk -F '\t' -v s="$staged" '$1 == s { print $2; exit }')"
  [[ -n "$mapping" ]] || continue

  check_doc "$mapping"
  case $? in
    0) ;;
    1)
      VIOLATIONS+=("${staged}${TAB}${mapping}")
      [[ $DOC_UNSTAGED_CLEAN -eq 1 ]] && UNSTAGED_CLEAN+=("$mapping")
      ;;
    *)
      warn "commit check skipped for ${mapping}: could not read it"
      ;;
  esac
done < <(git diff --cached --name-only --diff-filter=ACMR -z)

# (5) result
[[ ${#VIOLATIONS[@]} -eq 0 ]] && exit 0

# (6) work-in-progress commit
if message_has_wip; then
  warn "[wip] commit: allowed, but these docs still have change-review markup:"
  for entry in "${VIOLATIONS[@]}"; do
    printf '  %s\n' "${entry#*${TAB}}" >&2
  done
  exit 0
fi

print_block_message
exit 1
