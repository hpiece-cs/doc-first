# doc-first — A workflow where documents reach code before code does

> [English](README.md) · [한국어](README.ko.md)

A skill that applies Document-First implementation-stage rules across multi-AI-CLI environments. Even when a code modification, implementation, or refactoring request arrives, the source is not touched immediately; instead, a pre-implementation document is first authored and reviewed in `docs/src-notes/`, and only then does the code work proceed.

## Why is it needed?

AI CLIs (Claude Code, Codex, Copilot, Gemini, OpenCode, etc.) excel at editing code instantly from a single line of prompt, but that is also their **greatest source of risk**. When a one-liner like "change this function" causes the AI to reason internally and immediately edit the file, the following problems accumulate.

- **Intent–outcome mismatch** — There is no opportunity to verify whether the scope the AI decided in its head matches the scope the user expected.
- **Tacit decisions baked into code** — Decisions such as signature changes or branch additions get embedded into code without review.
- **Permanent doc/implementation desync** — Once they diverge, no document can be trusted anymore.
- **Volatile-context dependence** — A subsequent session can only see the code and will never know "why it was written this way."

doc-first blocks this pattern head-on. **For every code-edit request, the document must be updated and pass user confirmation before the actual edit begins.**

## What sets doc-first apart

Four design decisions that decisively distinguish it from other plan-first / spec-first tools.

### 1. Every code edit is a trigger — the finest granularity

Methodologies like `writing-plans`, BMAD, and GSD operate at the **phase / story / feature** level. That is, they are powerful for large tasks but small requests like "just change this one line of a function" slip through the net. The accumulation of small changes is the main pathway by which a codebase breaks down.

doc-first enforces the four-step procedure on **every prompt that may produce an edit**, regardless of volume or urgency. Rationalizations like "it's one line, skip it" are classified as Red Flags and blocked outright.

### 2. Four-level mirroring + path flattening for source↔document 1:1 mapping

```
src/services/auth/login.ts                   →  docs/src-notes/src/services/auth/login.ts.md
src/services/auth/oauth/google.ts            →  docs/src-notes/src/services/auth/oauth/google.ts.md
src/services/auth/oauth/providers/github.ts  →  docs/src-notes/src/services/auth/oauth/providers__github.ts.md
```

Counting directory depth under `docs/src-notes/`, **folders up to level 4 are kept as real directories**, and from level 5 onward the path is flattened by replacing `/` with `__`. Documents no longer pile up flat in a single folder, yet each source path still maps mechanically to exactly one document path.

For this mapping to be deterministic, **the documentation target source roots must be stated explicitly**. doc-first requires listing source roots such as `src/`, `lib/`, `app/`, or `packages/<pkg>/src/` at the top of `docs/src-notes/INDEX.md`, then applying the same rule within each root.

This convention may look like a simple naming rule, but in practice it is **a device that makes document discoverability deterministic**.

- Regardless of which file the AI modifies, it can locate the corresponding document immediately without inference.
- The mere absence of a document signals "the pre-implementation document is missing."
- A single grep tells you the document coverage for the entire source tree.

Unlike the free-form plan files of other tools, doc-first's document tree is **a structural mirror of the source tree**.

In addition, `docs/src-notes/INDEX.md` organizes the entire project's source files and their corresponding documents into a single table, so both AI and humans can grasp the full coverage in one lookup.

### 3. Four-layer docs structure — roles never overlap

| Directory | Role |
|---|---|
| `docs/spec-notes/` | Standards · guidelines · shared assets (baselines that are near-invariant) |
| `docs/src-notes/` | Folder/file-level pre-implementation documents (synchronized with code) |
| `docs/flow-notes/` | Flow · structure · architecture (perspective-only) |
| `docs/test-notes/` | Per-stage / per-run tests (time-axis record) |

Each directory explicitly follows the **no-role-overlap** principle. Rules such as "for shared assets, inline copying is forbidden; reference by link only" are enforced, which structurally prevents the same information from being scattered across multiple documents and triggering source-of-truth disputes.

### 4. Approved-Scope-Only + immediate halt & re-approval

Most plan-first tools follow "plan separately, execute separately," making it hard to notice when scope expands during execution. doc-first monitors the following during implementation as well.

- Creating/modifying files or folders not present in the document
- Changing function/variable signatures
- Adding, deleting, or changing branches/control flow
- Changes affecting external dependencies, `spec-notes`, or `flow-notes`

If any one occurs, **halt immediately → update document → re-confirm → resume**. The common trap of "let's fix this together while we're at it to make it cleaner" is explicitly blocked.

## Comparison — tools that look similar but differ

| Tool | Operating unit | Output persistence | Source↔doc mapping | Blocks every code edit |
|---|---|---|---|---|
| **doc-first** | File · folder | Persistent (synced with code) | Deterministic 1:1 | ✅ |
| superpowers:writing-plans | Task (multi-step) | One-off plan file | None | ❌ |
| GSD plan-phase | Phase | Archived after phase ends | Loose | ❌ |
| BMAD create-prd, etc. | Product · story | Persistent (high level) | None | ❌ |
| TDD | Function · feature | Test code | Test code itself is the mapping | ❌ |

doc-first **has the strongest enforcement at the smallest granularity.** It does not compete with the other tools; it reinforces the layer they do not cover.

## Which teams and tasks does it suit?

**Suitable situations**
- Multi-person collaboration or long-term collaboration with AI agents — when you want to break free of volatile-context dependence
- Core business logic, authentication, payments, data integrity code — areas where a small change can cause a large incident
- Brownfield codebases — environments where tracing "why it was written this way" is always insufficient
- Concurrent use of multiple AI CLIs — when consistent procedures across tools are needed

**Unsuitable situations**
- One-off scripts, learning code, prototypes destined for disposal
- Read · explore · pure documentation work (covered by the SKIP condition in the skill description)

## One-line summary

> **A skill that lets you tell the AI not "fix the code" but "before fixing, update the document and show me," without having to type that prompt every time yourself.**

## Core principles (summary)

1. **Document-First** — Four-step procedure: scope outline → `docs/src-notes/` pre-reflection → user confirmation → proceed after review
2. **Approved-Scope-Only** — Implement only the scope approved in review. On deviation, halt → re-approve → resume immediately

For full rules, see [`dist/SKILL.md`](dist/SKILL.md). The Korean source lives in the development repository as `core/SKILL.md`.

## Supported platforms

| Platform | Install path | Status |
|---|---|---|
| Claude Code | `~/.claude/skills/doc-first/SKILL.md` | ✅ Supported |
| Codex CLI | `${CODEX_HOME:-~/.codex}/skills/doc-first/SKILL.md` | ✅ Supported |
| Copilot CLI | `~/.copilot/skills/doc-first/SKILL.md` | ✅ Supported |
| Gemini CLI | `~/.gemini/extensions/doc-first/` (extension package) | ✅ Supported |
| OpenCode | `~/.config/opencode/skills/doc-first/SKILL.md` + `/doc-first` command | ✅ Supported |

## Installation

Pick **one** method per platform. Applying two methods to the same platform registers the gate hook twice on Claude Code, so the deny message is printed twice.

| Platform | Recommended method |
|---|---|
| Claude Code | Plugin (`/plugin marketplace add`) — registers the skill and the gate hook together |
| Gemini CLI | Clone the repository and run `./install.sh --target=gemini` — registers the skill and the gate hook together. The extension (`gemini extensions install`) installs the skill only |
| Codex CLI, Copilot CLI, OpenCode | Clone the repository and run `./install.sh` |

### Claude Code: install as a plugin

```
/plugin marketplace add hpiece-cs/doc-first
/plugin install doc-first@doc-first
```

This repository is both the marketplace and the plugin. The skill, the PreToolUse gate hook, and the SessionStart hook (automatic commit check installation) are registered together in plugin scope; `~/.claude/settings.json` is left untouched.

```
claude plugin update doc-first@doc-first    # update (applies after restart)
/plugin uninstall doc-first@doc-first       # remove
```

### Gemini CLI: install as an extension

```
gemini extensions install https://github.com/hpiece-cs/doc-first
```

The root `gemini-extension.json`, `GEMINI.md`, and `skills/doc-first/` are recognized as the extension. Update with `gemini extensions update doc-first`; remove with `gemini extensions uninstall doc-first`. This method installs the skill body only and does not register the [edit gate](#edit-gate-blocking-code-edits-before-approval); to get the gate too, use `./install.sh --target=gemini` below instead.

### All platforms: clone the repository and run install.sh

```bash
git clone https://github.com/hpiece-cs/doc-first.git
cd doc-first
./install.sh
```

Run without arguments to detect and install to every platform that exists in your home directory among `~/.claude/skills`, `${CODEX_HOME:-~/.codex}/skills`, `~/.copilot/skills`, `~/.gemini/extensions`, and `~/.config/opencode`. To update, run `git pull` and then `./install.sh` again.

#### Install to a specific platform

```bash
./install.sh --target=claude-code
./install.sh --target=codex
./install.sh --target=copilot
./install.sh --target=gemini
./install.sh --target=opencode
```

#### Install to all platforms

```bash
./install.sh --target=all
```

#### Preview (dry run)

```bash
./install.sh --dry-run
./install.sh --target=claude-code --dry-run
```

#### Uninstall

```bash
./install.sh --uninstall
./install.sh --uninstall --target=copilot
./install.sh --uninstall --target=opencode
```

#### Per-platform install behavior

- `claude-code`, `codex`, `copilot` — Copies SKILL.md into the flat layout (`<dest>/SKILL.md`) and copies the conditional detailed references into `<dest>/references/`
- All targets — copy the edit gate and the commit check tools to `~/.local/share/doc-first/bin/` and register the gate hook for each target (see [Edit gate](#edit-gate-blocking-code-edits-before-approval), [Commit check](#commit-check-keeping-docs-current))
- `claude-code` — Also registers the gate hook (PreToolUse Write|Edit) and the SessionStart hook in `~/.claude/settings.json` (requires `jq`; without it only the hooks are skipped)
- `gemini` — Places `gemini-extension.json` · `GEMINI.md` + SKILL.md into the extension package layout (`<dest>/skills/doc-first/SKILL.md`) and copies references alongside it
- `opencode` — Copies SKILL.md to `~/.config/opencode/skills/doc-first/SKILL.md` and places references plus the manual-invocation `/doc-first` command alongside the skill

## How it works

1. Each platform's skill discovery reads the YAML frontmatter (`name`, `description`) at the top of SKILL.md and loads the metadata into the system prompt
2. When the user sends a code modification/implementation request, it matches the description's trigger keywords and the body is activated
3. Once activated, follow the four-step procedure: `docs/src-notes/` pre-reflection → user confirmation → code work

OpenCode can load `doc-first` on demand via the native skill tool; for explicit invocation, use the `/doc-first <request>` command.

It does not trigger for read · explore · documentation-only work (per the SKIP condition in the description).

## Edit gate (blocking code edits before approval)

An edit gate is installed together with the skill body. In sessions where the doc-first procedure has not been completed, it blocks the AI tool right before it modifies a source file and points to the procedure. The gate walks up from the current working directory and treats the first directory containing `docs/src-notes/` as the doc-first project, so it does nothing in projects without that folder. Documentation, test and configuration files are not gated. Once the procedure is complete, creating the sentinel file the gate points to releases it for the rest of that session.

All five tools run the same gate script (`~/.local/share/doc-first/bin/pre-tool-use.sh`), so the rules are identical; only the registration differs per tool.

| Tool | Intercepted edit actions | Registration |
|---|---|---|
| Claude Code | `Write`, `Edit` | `~/.claude/settings.json` (plugin: `hooks/hooks.json`) |
| Gemini CLI | `write_file`, `replace` | `~/.gemini/settings.json` |
| Copilot CLI | `create`, `edit`, `str_replace_editor`, `apply_patch` | `~/.copilot/hooks/doc-first.json` |
| Codex CLI | `apply_patch` | `~/.codex/hooks.json` |
| OpenCode | `write`, `edit`, `apply_patch` | `~/.config/opencode/plugins/doc-first-gate.js` |

- The gate needs `jq`. Without it only the gate is disabled; the tool keeps working
- Codex CLI has an open upstream bug ([openai/codex#27833](https://github.com/openai/codex/issues/27833)) where a hook denial of `apply_patch` is ignored. The hook is registered, but it cannot block until that bug is fixed
- Edits made through shell commands (`sed -i`, redirection, …) are not blocked in any tool; only edit-tool calls are intercepted
- If you installed an earlier version, run `git pull` and `./install.sh` again: the gate moves to its new location and is registered for the other tools

## Commit check (keeping docs current)

When existing source is changed, the doc-first document first switches to the **change-review format** (post-change body plus 🟢🟠🔴 markers). Once the implementation is done, the markers must be removed so the document is the current source guide again. The commit check makes sure this last step is not skipped.

- When you commit a source file whose document (per `docs/src-notes/INDEX.md`) still has change-review markup, **the commit is aborted** and the cleanup command is shown
- Cleanup: `~/.local/share/doc-first/bin/review-clean.sh <doc>` → `git add <doc>` → commit again
- For work-in-progress commits mid-implementation, put `[wip]` in the commit message; the check only warns
- It runs as a git hook, so it works the same from the terminal, an IDE, or any Git GUI

### Enabling the commit check in a repository

| Environment | How |
|---|---|
| Claude Code | Automatic. Installed when a session starts in a doc-first repository |
| Codex, Copilot, Gemini CLI, OpenCode, or no AI | After installing, run once: `./install.sh --git-hooks=<folder containing your repositories>`. Run it again when you clone a new doc-first repository |
| Installed as a Gemini CLI extension | `~/.gemini/extensions/doc-first/install.sh --git-hooks=<folder>` |

```bash
./install.sh --git-hooks=~/Work               # install into doc-first repositories under ~/Work
./install.sh --git-hooks=~/Work --uninstall   # remove (an existing commit-msg hook is restored)
```

- An existing `commit-msg` hook is kept and chained so that it runs first
- Repositories that use `core.hooksPath` (husky, etc.) are not modified; the line to add to that hook is printed instead
- No global git settings are changed. Repositories that are not doc-first are not affected
- Requires `perl` (included by default on macOS, Linux, and Git for Windows)

### Limits

The commit check runs **only as a git hook on each machine**. It cannot stop:

- Commits made with `git commit --no-verify`
- Commits made on a machine or in a repository where the hook is not installed
- No server-side check (push rejection, CI) is provided

## License

MIT
