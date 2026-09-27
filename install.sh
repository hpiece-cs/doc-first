#!/usr/bin/env bash
#
# doc-first skill installer
#
# Usage:
#   ./install.sh                          # auto-detect target
#   ./install.sh --target=claude-code     # explicit target
#   ./install.sh --target=codex
#   ./install.sh --target=copilot
#   ./install.sh --target=opencode
#   ./install.sh --target=all             # install to all detected targets
#   ./install.sh --uninstall              # remove from all installed targets
#   ./install.sh --dry-run                # print actions without executing
#   ./install.sh --git-hooks=<dir>        # install the git commit check hook into
#                                         # every doc-first repository under <dir>
#   ./install.sh --git-hooks=<dir> --uninstall   # remove it from those repositories
#
# Supported targets:
#   - claude-code  →  ~/.claude/skills/doc-first/SKILL.md
#   - codex        →  ~/.codex/skills/doc-first/SKILL.md
#   - copilot      →  ~/.copilot/skills/doc-first/SKILL.md
#   - gemini       →  ~/.gemini/extensions/doc-first/  (extension package)
#   - opencode     →  ~/.config/opencode/skills/doc-first/SKILL.md
#   Bundled references are installed next to SKILL.md as references/.
#                     + ~/.config/opencode/{command|commands}/doc-first.md
#
# Adapter precedence (highest first):
#   adapters/<target>/SKILL.md   target-specific adapter, if present
#   dist/SKILL.md                English distribution build (produced by scripts/build.sh)
#   core/SKILL.md                Korean development source (final fallback)
#
# Shared tools (every target):
#   pre-tool-use.sh (edit gate), review-clean.sh, commit-msg-check.sh and
#   install-git-hook.sh are copied to ${XDG_DATA_HOME:-~/.local/share}/doc-first/bin/.
#   The git commit-msg hook in each doc-first repository and every edit gate
#   registration call them by absolute path.
#   --uninstall removes the tools folder once no target remains installed.
#
# Edit gate (every target): the gate is registered so that the tool runs it
# before each file edit. Unlock: after finishing the doc-first procedure,
# touch the sentinel file named in the denial message (valid for the session).
#   - claude-code  ~/.claude/settings.json      PreToolUse  Write|Edit
#   - gemini       ~/.gemini/settings.json      BeforeTool  write_file|replace
#   - codex        ~/.codex/hooks.json          PreToolUse  apply_patch
#   - copilot      ~/.copilot/hooks/doc-first.json (own file, no matcher)
#   - opencode     <config>/plugins/doc-first-gate.js (hooks/opencode-plugin.js)
#   JSON registrations need jq (without it only the registration is skipped).
#   Backups: <file>.bak.doc-first
#
# Claude Code also gets a SessionStart hook (~/.claude/hooks/doc-first-session.sh)
# that installs the git commit check hook automatically. Other tools: run
# install-git-hook.sh inside the repository or use --git-hooks=<dir>.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="doc-first"
CORE_SKILL="${SCRIPT_DIR}/core/SKILL.md"
DIST_SKILL="${SCRIPT_DIR}/dist/SKILL.md"
HOOK_MARKER="doc-first-gate"   # marker for the edit gate entry (same in every hook file)
SESSION_HOOK_SRC="${SCRIPT_DIR}/hooks/session-start.sh"
SESSION_MARKER="doc-first-session"   # marker for the SessionStart entry
BIN_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/doc-first/bin"
BIN_TOOLS=(review-clean.sh commit-msg-check.sh install-git-hook.sh pre-tool-use.sh)
GATE_SCRIPT="${BIN_DIR}/pre-tool-use.sh"   # every gate registration points here
OPENCODE_PLUGIN_SRC="${SCRIPT_DIR}/hooks/opencode-plugin.js"
CODEX_GATE_NOTICE="Codex: apply_patch deny is currently ignored by Codex (openai/codex#27833); the gate takes effect once that is fixed."

TARGET=""
DRY_RUN=0
UNINSTALL=0
GIT_HOOKS_DIR=""

# ---- Target table ---------------------------------------------------------

target_path() {
  case "$1" in
    claude-code) echo "${HOME}/.claude/skills/${SKILL_NAME}" ;;
    codex)       echo "${CODEX_HOME:-${HOME}/.codex}/skills/${SKILL_NAME}" ;;
    copilot)     echo "${HOME}/.copilot/skills/${SKILL_NAME}" ;;
    gemini)      echo "${HOME}/.gemini/extensions/${SKILL_NAME}" ;;
    opencode)    echo "$(opencode_config_dir)/skills/${SKILL_NAME}" ;;
    *) return 1 ;;
  esac
}

opencode_config_dir() {
  echo "${OPENCODE_CONFIG_HOME:-${XDG_CONFIG_HOME:-${HOME}/.config}/opencode}"
}

opencode_command_dir() {
  local config_dir
  config_dir="$(opencode_config_dir)"

  if [[ -d "${config_dir}/command" ]]; then
    echo "${config_dir}/command"
  else
    echo "${config_dir}/commands"
  fi
}

target_marker() {
  # A directory whose existence indicates the platform is installed.
  case "$1" in
    claude-code) echo "${HOME}/.claude/skills" ;;
    codex)       echo "${CODEX_HOME:-${HOME}/.codex}/skills" ;;
    copilot)     echo "${HOME}/.copilot/skills" ;;
    gemini)      echo "${HOME}/.gemini/extensions" ;;
    opencode)    echo "$(opencode_config_dir)" ;;
    *) return 1 ;;
  esac
}

ALL_TARGETS=(claude-code codex copilot gemini opencode)

# ---- Helpers --------------------------------------------------------------

log()   { printf '\033[36m[doc-first]\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m[doc-first]\033[0m %s\n' "$*" >&2; }
error() { printf '\033[31m[doc-first]\033[0m %s\n' "$*" >&2; exit 1; }

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '\033[2m  $ %s\033[0m\n' "$*"
  else
    "$@"
  fi
}

resolve_skill_source() {
  # dist/SKILL.md (English build) > core/SKILL.md (Korean source)
  if [[ -f "$DIST_SKILL" ]]; then
    echo "$DIST_SKILL"
  else
    warn_dist_missing_once
    echo "$CORE_SKILL"
  fi
}

DIST_WARNED=0
warn_dist_missing_once() {
  if [[ "$DIST_WARNED" -eq 0 ]]; then
    warn "dist/SKILL.md not found — falling back to core/SKILL.md (Korean development source)."
    warn "  Run ./scripts/build.sh to produce the English distribution build."
    DIST_WARNED=1
  fi
}

source_for_target() {
  local t="$1"
  local adapter="${SCRIPT_DIR}/adapters/${t}/SKILL.md"
  if [[ -f "$adapter" ]]; then
    echo "$adapter"
  else
    resolve_skill_source
  fi
}

install_references_for_source() {
  local skill_src="$1"
  local dest_dir="$2"
  local ref_src
  ref_src="$(dirname "$skill_src")/references"

  if [[ ! -d "$ref_src" ]]; then
    return 0
  fi

  log "Installing references: ${dest_dir}/references/"
  run rm -rf "${dest_dir}/references"
  run mkdir -p "${dest_dir}/references"
  run cp -R "${ref_src}/." "${dest_dir}/references/"
}

detect_targets() {
  local detected=()
  for t in "${ALL_TARGETS[@]}"; do
    if [[ -d "$(target_marker "$t")" ]]; then
      detected+=("$t")
    fi
  done
  printf '%s\n' "${detected[@]}"
}

install_one() {
  local t="$1"
  local dest_dir
  dest_dir="$(target_path "$t")" || error "Unknown target: $t"

  case "$t" in
    gemini)
      install_gemini "$dest_dir"
      ;;
    opencode)
      install_opencode "$dest_dir"
      ;;
    *)
      install_simple_skill "$t" "$dest_dir"
      ;;
  esac

  # Edit gate registration, per target
  case "$t" in
    claude-code)
      install_claude_code_hook
      ;;
    gemini)
      register_gate_hook "${HOME}/.gemini/settings.json" "BeforeTool" "write_file|replace" "gemini" || true
      ;;
    codex)
      if register_gate_hook "${CODEX_HOME:-${HOME}/.codex}/hooks.json" "PreToolUse" "apply_patch" "codex"; then
        warn "$CODEX_GATE_NOTICE"
      fi
      ;;
    copilot)
      install_copilot_hook
      ;;
    opencode)
      install_opencode_plugin
      ;;
  esac
}

install_simple_skill() {
  # Flat layout: <dest_dir>/SKILL.md
  local t="$1"
  local dest_dir="$2"
  local src
  src="$(source_for_target "$t")"

  if [[ ! -f "$src" ]]; then
    error "Source not found: $src"
  fi

  log "Installing to ${t}: ${dest_dir}/SKILL.md"
  run mkdir -p "$dest_dir"
  run cp "$src" "${dest_dir}/SKILL.md"
  install_references_for_source "$src" "$dest_dir"
}

install_gemini() {
  # Gemini extension layout:
  #   <dest>/gemini-extension.json
  #   <dest>/GEMINI.md
  #   <dest>/skills/doc-first/SKILL.md
  local dest_dir="$1"
  local adapter_dir="${SCRIPT_DIR}/adapters/gemini"

  if [[ ! -f "${adapter_dir}/gemini-extension.json" ]] || [[ ! -f "${adapter_dir}/GEMINI.md" ]]; then
    error "Gemini adapter files missing in ${adapter_dir}"
  fi

  log "Installing to gemini: ${dest_dir}/"
  local skill_src
  skill_src="$(resolve_skill_source)"
  run mkdir -p "${dest_dir}/skills/${SKILL_NAME}"
  run cp "${adapter_dir}/gemini-extension.json" "${dest_dir}/gemini-extension.json"
  run cp "${adapter_dir}/GEMINI.md"               "${dest_dir}/GEMINI.md"
  run cp "$skill_src"                             "${dest_dir}/skills/${SKILL_NAME}/SKILL.md"
  install_references_for_source "$skill_src"      "${dest_dir}/skills/${SKILL_NAME}"
}

install_opencode() {
  # OpenCode native skill + manual command:
  #   <config>/skills/doc-first/SKILL.md
  #   <config>/{command|commands}/doc-first.md
  local skill_dir="$1"
  local command_dir
  local command_src="${SCRIPT_DIR}/adapters/opencode/doc-first.md"
  local skill_src

  if [[ ! -f "$command_src" ]]; then
    error "OpenCode command adapter not found: $command_src"
  fi

  command_dir="$(opencode_command_dir)"
  skill_src="$(resolve_skill_source)"

  log "Installing to opencode skill: ${skill_dir}/SKILL.md"
  run mkdir -p "$skill_dir"
  run cp "$skill_src" "${skill_dir}/SKILL.md"
  install_references_for_source "$skill_src" "$skill_dir"

  log "Installing to opencode command: ${command_dir}/${SKILL_NAME}.md"
  run mkdir -p "$command_dir"
  run cp "$command_src" "${command_dir}/${SKILL_NAME}.md"
}

uninstall_one() {
  local t="$1"
  local dest_dir
  dest_dir="$(target_path "$t")" || error "Unknown target: $t"

  # Edit gate removal, per target (opencode: inside uninstall_opencode)
  case "$t" in
    claude-code) uninstall_claude_code_hook ;;
    gemini)      unregister_gate_hook "${HOME}/.gemini/settings.json" "BeforeTool" ;;
    codex)       unregister_gate_hook "${CODEX_HOME:-${HOME}/.codex}/hooks.json" "PreToolUse" ;;
    copilot)     uninstall_copilot_hook ;;
  esac

  if [[ "$t" == "opencode" ]]; then
    uninstall_opencode "$dest_dir"
    return 0
  fi

  if [[ ! -d "$dest_dir" ]]; then
    log "Skip ${t}: not installed"
    return 0
  fi

  log "Removing ${t}: ${dest_dir}"
  run rm -rf "$dest_dir"
}

register_gate_hook() {
  # Register the edit gate (GATE_SCRIPT --tool=<tool>) in a hooks JSON file
  # (~/.claude/settings.json, ~/.gemini/settings.json, ~/.codex/hooks.json all
  # share the top-level hooks.<event>[] layout). Idempotent via HOOK_MARKER.
  # Returns 1 when the registration was skipped.
  local settings="$1" event="$2" matcher="$3" tool="$4"
  local command_line="\"${GATE_SCRIPT}\" --tool=${tool}"

  if [[ "$DRY_RUN" -ne 1 && ! -f "$GATE_SCRIPT" ]]; then
    warn "Edit gate missing: ${GATE_SCRIPT} (skip gate registration for ${tool})"
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    warn "jq not found — edit gate NOT registered for ${tool}. Install jq and re-run, or add this hook manually:"
    warn "  ${settings}: ${event} (matcher: ${matcher:-none}) → ${command_line}"
    return 1
  fi

  if [[ ! -f "$settings" ]]; then
    log "Creating empty hooks file: ${settings}"
    run mkdir -p "$(dirname "$settings")"
    if [[ "$DRY_RUN" -ne 1 ]]; then
      printf '{}\n' > "$settings"
    else
      printf '\033[2m  $ printf "{}\\n" > %s\033[0m\n' "$settings"
    fi
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '\033[2m  $ jq merge %s hook (%s) into %s (marker: %s)\033[0m\n' "$event" "$command_line" "$settings" "$HOOK_MARKER"
    return 0
  fi

  # Backup (idempotent — overwritten with the same name)
  cp "$settings" "${settings}.bak.doc-first"
  merge_settings_hook "$settings" "$event" "$matcher" "$command_line" "$HOOK_MARKER"
  log "Edit gate registered (${event} ${matcher:-*}) in ${settings}"
  log "Backup saved: ${settings}.bak.doc-first"
  return 0
}

unregister_gate_hook() {
  # Remove the edit gate entry from a hooks JSON file.
  local settings="$1" event="$2"

  if [[ ! -f "$settings" ]]; then
    return 0
  fi

  if ! command -v jq >/dev/null 2>&1; then
    warn "jq not found — cannot clean ${settings}. Remove the ${HOOK_MARKER} entry manually."
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '\033[2m  $ jq filter %s entry from %s\033[0m\n' "$HOOK_MARKER" "$settings"
    return 0
  fi

  cp "$settings" "${settings}.bak.doc-first"
  remove_settings_hook "$settings" "$event" "$HOOK_MARKER"
}

install_claude_code_hook() {
  # Claude Code: edit gate (PreToolUse Write|Edit) plus the SessionStart hook
  # (~/.claude/hooks/doc-first-session.sh), both in ~/.claude/settings.json.
  local settings="${HOME}/.claude/settings.json"
  local session_dest="${HOME}/.claude/hooks/doc-first-session.sh"

  if ! register_gate_hook "$settings" "PreToolUse" "Write|Edit" "claude"; then
    return 0   # gate skipped (no gate script / no jq): the session hook needs the same tools
  fi

  if [[ ! -f "$SESSION_HOOK_SRC" ]]; then
    warn "Session hook source missing: ${SESSION_HOOK_SRC} (skip SessionStart hook)"
    return 0
  fi

  log "Installing hook script: ${session_dest}"
  run mkdir -p "$(dirname "$session_dest")"
  run cp "$SESSION_HOOK_SRC" "$session_dest"
  run chmod +x "$session_dest"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '\033[2m  $ jq merge SessionStart hook into %s (marker: %s)\033[0m\n' "$settings" "$SESSION_MARKER"
    return 0
  fi

  cp "$settings" "${settings}.bak.doc-first"
  merge_settings_hook "$settings" "SessionStart" "" "$session_dest" "$SESSION_MARKER"
  log "Hook registered (SessionStart) in ${settings}"
  log "First-time activation: open /hooks once or restart Claude Code to load the new hooks"
}

uninstall_claude_code_hook() {
  local settings="${HOME}/.claude/settings.json"
  local legacy_gate="${HOME}/.claude/hooks/doc-first-gate.sh"   # install location before the shared BIN_DIR
  local session_dest="${HOME}/.claude/hooks/doc-first-session.sh"
  local script

  for script in "$session_dest" "$legacy_gate"; do
    if [[ -f "$script" ]]; then
      log "Removing hook script: ${script}"
      run rm -f "$script"
    fi
  done

  unregister_gate_hook "$settings" "PreToolUse"

  if [[ ! -f "$settings" ]]; then
    return 0
  fi

  if ! command -v jq >/dev/null 2>&1; then
    warn "jq not found — cannot clean settings.json. Remove the ${SESSION_MARKER} entry manually."
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '\033[2m  $ jq filter %s entry from %s\033[0m\n' "$SESSION_MARKER" "$settings"
    return 0
  fi

  cp "$settings" "${settings}.bak.doc-first"
  remove_settings_hook "$settings" "SessionStart" "$SESSION_MARKER"
}

install_copilot_hook() {
  # Copilot CLI reads every JSON file under ~/.copilot/hooks/, so the gate gets
  # its own file (no merge). There is no matcher: the gate filters edit tools.
  local hook_file="${HOME}/.copilot/hooks/doc-first.json"

  if [[ "$DRY_RUN" -ne 1 && ! -f "$GATE_SCRIPT" ]]; then
    warn "Edit gate missing: ${GATE_SCRIPT} (skip gate registration for copilot)"
    return 0
  fi

  log "Installing copilot hook: ${hook_file}"
  run mkdir -p "$(dirname "$hook_file")"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '\033[2m  $ write preToolUse hook (%s --tool=copilot) to %s\033[0m\n' "$GATE_SCRIPT" "$hook_file"
    return 0
  fi

  cat > "$hook_file" <<EOF
{
  "version": 1,
  "hooks": {
    "preToolUse": [
      {
        "type": "command",
        "bash": "\\"${GATE_SCRIPT}\\" --tool=copilot",
        "timeoutSec": 10
      }
    ]
  }
}
EOF
  log "Edit gate registered (preToolUse) in ${hook_file}"
}

uninstall_copilot_hook() {
  local hook_file="${HOME}/.copilot/hooks/doc-first.json"
  if [[ -f "$hook_file" ]]; then
    log "Removing copilot hook: ${hook_file}"
    run rm -f "$hook_file"
  fi
}

install_opencode_plugin() {
  # OpenCode has no shell hooks: a JS plugin runs the gate script instead.
  local plugin_dest
  plugin_dest="$(opencode_config_dir)/plugins/doc-first-gate.js"

  if [[ ! -f "$OPENCODE_PLUGIN_SRC" ]]; then
    warn "OpenCode plugin source missing: ${OPENCODE_PLUGIN_SRC} (skip gate plugin)"
    return 0
  fi

  log "Installing opencode plugin: ${plugin_dest}"
  run mkdir -p "$(dirname "$plugin_dest")"
  run cp "$OPENCODE_PLUGIN_SRC" "$plugin_dest"
}

merge_settings_hook() {
  # Idempotently add one doc-first entry to .hooks.<event> in a hooks JSON file:
  # entries whose command contains the marker are removed, then the new one
  # is appended. An empty matcher omits the "matcher" key.
  local settings="$1" event="$2" matcher="$3" command_path="$4" marker="$5"
  local entry merged

  entry=$(jq -n --arg cmd "$command_path" --arg marker "$marker" --arg matcher "$matcher" '
    { hooks: [{ type: "command", command: ($cmd + "  # " + $marker) }] }
    + (if $matcher == "" then {} else { matcher: $matcher } end)
  ')

  if ! merged=$(jq --argjson entry "$entry" --arg event "$event" --arg marker "$marker" '
    .hooks //= {} |
    .hooks[$event] //= [] |
    .hooks[$event] |= map(select(
      ((.hooks // []) | map(.command // "" | test($marker)) | any) | not
    )) |
    .hooks[$event] += [$entry]
  ' "$settings" 2>&1); then
    error "jq merge failed: $merged"
  fi

  printf '%s\n' "$merged" > "${settings}.tmp"
  mv "${settings}.tmp" "$settings"

  if ! jq -e --arg event "$event" --arg marker "$marker" '
    .hooks[$event][]? | .hooks[]? | select(.command // "" | test($marker))
  ' "$settings" >/dev/null; then
    error "Hook registration verification failed in ${settings}"
  fi
}

remove_settings_hook() {
  # Remove doc-first entries (matched by marker) from .hooks.<event>.
  local settings="$1" event="$2" marker="$3"
  local cleaned

  if ! cleaned=$(jq --arg event "$event" --arg marker "$marker" '
    if .hooks[$event] then
      .hooks[$event] |= map(select(
        ((.hooks // []) | map(.command // "" | test($marker)) | any) | not
      ))
    else . end
  ' "$settings" 2>&1); then
    warn "jq filter failed: $cleaned"
    return 0
  fi

  printf '%s\n' "$cleaned" > "${settings}.tmp"
  mv "${settings}.tmp" "$settings"
  log "Removed ${event} hook entry from ${settings}"
}

install_bin_tools() {
  # Copy the shared tools (commit check tools and the edit gate) to the fixed
  # path that git hooks and gate registrations call.
  local tool
  log "Installing shared tools: ${BIN_DIR}"
  run mkdir -p "$BIN_DIR"
  for tool in "${BIN_TOOLS[@]}"; do
    if [[ ! -f "${SCRIPT_DIR}/hooks/${tool}" ]]; then
      warn "Shared tool missing: hooks/${tool} (skipped)"
      continue
    fi
    run cp "${SCRIPT_DIR}/hooks/${tool}" "${BIN_DIR}/${tool}"
    run chmod +x "${BIN_DIR}/${tool}"
  done
}

uninstall_bin_tools() {
  if [[ -d "$BIN_DIR" ]]; then
    log "Removing shared tools: ${BIN_DIR}"
    run rm -rf "$BIN_DIR"
  fi
}

any_target_installed() {
  local t
  for t in "${ALL_TARGETS[@]}"; do
    if [[ -d "$(target_path "$t")" ]]; then
      return 0
    fi
  done
  return 1
}

uninstall_opencode() {
  local skill_dir="$1"
  local config_dir
  config_dir="$(opencode_config_dir)"

  if [[ -d "$skill_dir" ]]; then
    log "Removing opencode skill: ${skill_dir}"
    run rm -rf "$skill_dir"
  else
    log "Skip opencode skill: not installed"
  fi

  local command_file
  for command_file in \
    "${config_dir}/command/${SKILL_NAME}.md" \
    "${config_dir}/commands/${SKILL_NAME}.md"
  do
    if [[ -f "$command_file" ]]; then
      log "Removing opencode command: ${command_file}"
      run rm -f "$command_file"
    fi
  done

  local plugin_file="${config_dir}/plugins/doc-first-gate.js"
  if [[ -f "$plugin_file" ]]; then
    log "Removing opencode plugin: ${plugin_file}"
    run rm -f "$plugin_file"
  fi
}

find_doc_first_repos() {
  # Print every git repository under $1 whose top level has docs/src-notes/.
  local base_dir="$1" src_notes candidate top_level
  while IFS= read -r src_notes; do
    candidate="$(cd "${src_notes%/docs/src-notes}" 2>/dev/null && pwd -P)" || continue
    top_level="$(git -C "$candidate" rev-parse --show-toplevel 2>/dev/null)" || continue
    top_level="$(cd "$top_level" && pwd -P)"
    if [[ "$top_level" == "$candidate" ]]; then
      printf '%s\n' "$candidate"
    fi
  done < <(find "$base_dir" \( -name .git -o -name node_modules \) -prune -o -type d -path '*/docs/src-notes' -print 2>/dev/null)
  return 0
}

manage_git_hooks_under() {
  # Install (or, with --uninstall, remove) the commit check hook in every
  # doc-first repository under $1. Skills for AI tools are not touched.
  local base_dir="$1" installer repos repo
  local processed=0 failed=0

  [[ -d "$base_dir" ]] || error "Folder not found: ${base_dir}"

  if [[ "$UNINSTALL" -eq 1 ]]; then
    # Removal does not depend on the tools path, so use the copy next to this script.
    installer="${SCRIPT_DIR}/hooks/install-git-hook.sh"
  else
    install_bin_tools
    installer="${BIN_DIR}/install-git-hook.sh"
    if [[ "$DRY_RUN" -ne 1 && ! -x "$installer" ]]; then
      error "Commit check tools not available: ${installer}"
    fi
  fi

  repos="$(find_doc_first_repos "$base_dir")"
  if [[ -z "$repos" ]]; then
    log "No doc-first repositories found under ${base_dir}"
    return 0
  fi

  while IFS= read -r repo; do
    [[ -n "$repo" ]] || continue
    processed=$((processed + 1))
    if [[ "$UNINSTALL" -eq 1 ]]; then
      run bash "$installer" --uninstall "$repo" || failed=$((failed + 1))
    else
      run bash "$installer" "$repo" || failed=$((failed + 1))
    fi
  done <<< "$repos"

  log "Repositories processed: ${processed} (failed: ${failed})"
}

# ---- Argument parsing -----------------------------------------------------

for arg in "$@"; do
  case "$arg" in
    --target=*)  TARGET="${arg#--target=}" ;;
    --dry-run)   DRY_RUN=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --git-hooks=*)
      GIT_HOOKS_DIR="${arg#--git-hooks=}"
      # "--git-hooks=~/dir" is not tilde-expanded by the shell
      if [[ "$GIT_HOOKS_DIR" == "~" || "$GIT_HOOKS_DIR" == "~/"* ]]; then
        GIT_HOOKS_DIR="${HOME}${GIT_HOOKS_DIR#\~}"
      fi
      [[ -n "$GIT_HOOKS_DIR" ]] || error "Unknown argument: $arg"
      ;;
    -h|--help)
      awk 'NR < 3 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
      exit 0
      ;;
    *) error "Unknown argument: $arg" ;;
  esac
done

# ---- Git hooks mode -------------------------------------------------------

if [[ -n "$GIT_HOOKS_DIR" ]]; then
  manage_git_hooks_under "$GIT_HOOKS_DIR"
  log "Done."
  exit 0
fi

# ---- Resolve target list --------------------------------------------------

TARGETS=()

read_targets_into_array() {
  TARGETS=()
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] && TARGETS+=("$line")
  done < <(detect_targets)
}

if [[ -n "$TARGET" ]]; then
  if [[ "$TARGET" == "all" ]]; then
    read_targets_into_array
    [[ ${#TARGETS[@]} -eq 0 ]] && error "No supported platforms detected."
  else
    target_path "$TARGET" >/dev/null || error "Unsupported target: $TARGET"
    TARGETS=("$TARGET")
  fi
else
  read_targets_into_array
  if [[ ${#TARGETS[@]} -eq 0 ]]; then
    error "No supported platforms detected. Use --target=<name> explicitly."
  fi
  if [[ ${#TARGETS[@]} -gt 1 ]]; then
    log "Auto-detected targets: ${TARGETS[*]}"
  fi
fi

# ---- Execute --------------------------------------------------------------

# Shared tools first: every gate registration points at GATE_SCRIPT in BIN_DIR.
if [[ "$UNINSTALL" -ne 1 ]]; then
  install_bin_tools
fi

for t in "${TARGETS[@]}"; do
  if [[ "$UNINSTALL" -eq 1 ]]; then
    uninstall_one "$t"
  else
    install_one "$t"
  fi
done

if [[ "$UNINSTALL" -eq 1 ]]; then
  if ! any_target_installed; then
    uninstall_bin_tools
  else
    log "Keeping shared tools (other targets still installed): ${BIN_DIR}"
  fi
else
  log "Commit check: Claude Code installs the git hook in each doc-first repository automatically."
  log "  Other tools or no AI: run once  ./install.sh --git-hooks=<folder containing your repositories>"
fi

log "Done."
