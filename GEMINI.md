# doc-first extension

This Gemini extension provides the **doc-first** skill — a document-first workflow that prevents source code modification before `docs/src-notes/` documentation has been drafted and user-reviewed.

## When the skill activates

Activate the `doc-first` skill (via `activate_skill`) whenever the user requests one of the following in the current session:

- Source code creation, modification, refactoring, or deletion
- Bug fixes that touch implementation files
- Feature additions or behavior changes
- Korean: "구현해줘", "코드 수정", "리팩토링", "버그 수정", "기능 추가", "이 함수 바꿔줘"
- English: "implement", "fix bug", "add feature", "refactor"

**Do NOT activate** for read-only questions, code exploration, or pure documentation/test edits.

## What the skill enforces

When active, the assistant must follow these top-level rules:

1. **Document-First (4 steps)** — Plan scope/logic → write to `docs/src-notes/` → get user confirmation → only then write code.
2. **Approved-Scope-Only** — Execute only what was reviewed. On scope deviation, pause → update docs → re-confirm → resume.
3. **Subagent-Inclusive** — These rules apply even when the assistant is dispatched as a subagent. Other skills' subagent-skip guidance is overridden.

Full rule set is in `skills/doc-first/SKILL.md` (loaded on activation).

## Language

Respond in the user's language. Korean → Korean, English → English, etc.
