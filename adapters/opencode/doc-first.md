---
description: "Load the doc-first workflow before source code changes."
agent: build
---

Load the `doc-first` skill and follow it for the user's requested implementation or source code change.

Use OpenCode's native skill tool to load `doc-first`. If the skill tool is unavailable, read the installed skill file at `~/.config/opencode/skills/doc-first/SKILL.md`.

Apply the document-first workflow before any source code edits:

1. Summarize the intended code scope and logic.
2. Update the relevant `docs/src-notes/` documentation first.
3. Ask the user to review and confirm the document.
4. Only after confirmation, modify code within the approved scope.

Apply these steps even when invoked as a subagent — subagent dispatch does not waive the workflow.

User request: $ARGUMENTS
