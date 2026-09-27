#!/usr/bin/env bash
#
# doc-first commit check hook installer
#
# Installs a git commit-msg stub into a doc-first repository (one that has
# docs/src-notes/). The stub runs commit-msg-check.sh from this directory by
# absolute path. An existing commit-msg hook is kept and chained: it is
# renamed to commit-msg.pre-doc-first and runs first.
#
# Usage:
#   install-git-hook.sh [--quiet] [--uninstall] [DIR]
#     DIR          any folder inside the repository (default: current folder)
#     --quiet      print nothing when there is nothing to do
#     --uninstall  remove the stub and restore the chained hook
#
# Repositories with core.hooksPath (husky, shared hook folders) are never
# modified automatically; the line to add by hand is printed instead.
#
# Exit codes: 0 done / nothing to do / manual step printed, 1 failed, 2 usage.

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_SCRIPT="${SCRIPT_DIR}/commit-msg-check.sh"
STUB_MARKER="doc-first-commit-check"
CHAINED_NAME="commit-msg.pre-doc-first"

QUIET=0
UNINSTALL=0
TARGET_DIR=""

usage() {
  sed -n '3,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

say() {
  [[ $QUIET -eq 1 ]] || echo "[doc-first] $*"
}

# ---- write_stub [F-02] ----------------------------------------------------
write_stub() {
  local hook_path="$1"
  local temp_path="${hook_path}.tmp.$$"
  {
    printf '#!/bin/sh\n'
    printf '# %s (installed by doc-first; see install-git-hook.sh)\n' "$STUB_MARKER"
    printf 'DOC_FIRST_CHECK="%s"\n' "$CHECK_SCRIPT"
    cat <<'STUB'
HOOK_DIR=$(dirname "$0")
if [ -x "$HOOK_DIR/commit-msg.pre-doc-first" ]; then
  "$HOOK_DIR/commit-msg.pre-doc-first" "$@" || exit $?
fi
if [ -x "$DOC_FIRST_CHECK" ]; then
  exec "$DOC_FIRST_CHECK" "$@"
fi
echo "[doc-first] commit check not found ($DOC_FIRST_CHECK); skipping" >&2
exit 0
STUB
  } > "$temp_path" && chmod +x "$temp_path" && mv "$temp_path" "$hook_path"
  local status=$?
  if [[ $status -ne 0 ]]; then
    rm -f "$temp_path"
    echo "[doc-first] failed to write commit check hook: ${hook_path}" >&2
    return 1
  fi
  return 0
}

is_doc_first_stub() {
  [[ -f "$1" ]] && grep -q "$STUB_MARKER" "$1"
}

uninstall_hook() {
  local hook_path="$1" chained_path="$2"
  if ! is_doc_first_stub "$hook_path"; then
    say "commit check hook not installed: ${hook_path}"
    return 0
  fi
  rm -f "$hook_path" || return 1
  if [[ -e "$chained_path" ]]; then
    mv "$chained_path" "$hook_path" || return 1
    echo "[doc-first] Removed commit check hook; restored previous commit-msg hook: ${hook_path}"
  else
    echo "[doc-first] Removed commit check hook: ${hook_path}"
  fi
  return 0
}

# ---- main [F-01] ----------------------------------------------------------

for arg in "$@"; do
  case "$arg" in
    --quiet)     QUIET=1 ;;
    --uninstall) UNINSTALL=1 ;;
    -h|--help)   usage; exit 0 ;;
    -*)          echo "[doc-first] unknown option: $arg" >&2; usage >&2; exit 2 ;;
    *)           TARGET_DIR="$arg" ;;
  esac
done
TARGET_DIR="${TARGET_DIR:-$PWD}"

# (1) git repository
if ! repo_root="$(git -C "$TARGET_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  say "not a git repository: ${TARGET_DIR}"
  exit 0
fi

# (2) doc-first project
if [[ ! -d "${repo_root}/docs/src-notes" ]]; then
  say "not a doc-first project (no docs/src-notes): ${repo_root}"
  exit 0
fi

common_dir="$(git -C "$repo_root" rev-parse --git-common-dir 2>/dev/null)" || exit 1
[[ "$common_dir" == /* ]] || common_dir="${repo_root}/${common_dir}"
hooks_dir="${common_dir}/hooks"
hook_path="${hooks_dir}/commit-msg"
chained_path="${hooks_dir}/${CHAINED_NAME}"

# (3) uninstall
if [[ $UNINSTALL -eq 1 ]]; then
  uninstall_hook "$hook_path" "$chained_path"
  exit $?
fi

# (4) custom hooks path: guide only (printed even with --quiet)
custom_hooks_path="$(git -C "$repo_root" config --get core.hooksPath 2>/dev/null)"
if [[ -n "$custom_hooks_path" ]]; then
  echo "[doc-first] core.hooksPath is set (${custom_hooks_path}) in ${repo_root}; commit check hook not installed automatically."
  echo "[doc-first] Add this line to the commit-msg hook in that folder:"
  echo "  \"${CHECK_SCRIPT}\" \"\$1\" || exit \$?"
  exit 0
fi

mkdir -p "$hooks_dir" || exit 1

# (5) already installed
if is_doc_first_stub "$hook_path"; then
  if grep -qF "DOC_FIRST_CHECK=\"${CHECK_SCRIPT}\"" "$hook_path"; then
    exit 0
  fi
  write_stub "$hook_path" || exit 1
  echo "[doc-first] Updated commit check hook: ${hook_path}"
  exit 0
fi

# (6) chain an existing commit-msg hook
if [[ -e "$hook_path" ]]; then
  if [[ -e "$chained_path" ]]; then
    echo "[doc-first] cannot chain the existing commit-msg hook: ${chained_path} already exists" >&2
    exit 1
  fi
  mv "$hook_path" "$chained_path" || exit 1
  if ! write_stub "$hook_path"; then
    mv "$chained_path" "$hook_path"
    exit 1
  fi
  echo "[doc-first] Installed commit check hook (existing hook kept as ${CHAINED_NAME}): ${hook_path}"
  exit 0
fi

write_stub "$hook_path" || exit 1
echo "[doc-first] Installed commit check hook: ${hook_path}"
exit 0
