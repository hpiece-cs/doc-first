#!/usr/bin/env bash
#
# doc-first SessionStart hook (Claude Code)
#
# 1) Keeps the shared tools (commit check tools and the edit gate) at a fixed
#    path. Plugin installs move with every plugin version, but git hooks and
#    the other AI tools' gate registrations need a stable path.
# 2) In a doc-first project (a folder with docs/src-notes/ at or above the
#    current folder), installs the git commit check hook if it is missing.
#
# Never fails: session start must not be blocked. Output (if any) is one
# short line that Claude Code adds to the session context.

BIN_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/doc-first/bin"
SHARED_SCRIPTS=(review-clean.sh commit-msg-check.sh install-git-hook.sh pre-tool-use.sh)
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- sync_bin [F-02] ------------------------------------------------------
sync_bin() {
  local name source target
  [[ -f "${SELF_DIR}/install-git-hook.sh" ]] || return 0   # install.sh layout
  mkdir -p "$BIN_DIR" 2>/dev/null || { echo "[doc-first] cannot create ${BIN_DIR}"; return 0; }
  for name in "${SHARED_SCRIPTS[@]}"; do
    source="${SELF_DIR}/${name}"
    target="${BIN_DIR}/${name}"
    [[ -f "$source" ]] || continue
    if ! cmp -s "$source" "$target"; then
      if ! { cp "$source" "$target" && chmod +x "$target"; } 2>/dev/null; then
        echo "[doc-first] cannot update ${target}"
      fi
    fi
  done
}

# ---- find_doc_first_root [F-03] -------------------------------------------
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

# ---- main [F-01] ----------------------------------------------------------

# Session info arrives on stdin; it is not needed.
if [[ ! -t 0 ]]; then
  cat >/dev/null 2>&1
fi

sync_bin

if ! project_root="$(find_doc_first_root "$PWD")"; then
  exit 0
fi

if [[ ! -x "${BIN_DIR}/install-git-hook.sh" ]]; then
  echo "[doc-first] commit check tools not installed (${BIN_DIR})"
  exit 0
fi

"${BIN_DIR}/install-git-hook.sh" --quiet "$project_root" 2>&1
exit 0
