# Post-Approval Code Authoring Principles

Apply this after the §1.1 document review and user confirmation are complete.

- **Prefer explicit expression** — Use variable/function names with clear intent; do not compress multiple meanings into one line
- **Avoid terse / clever code** — Bit tricks, multi-level ternaries, single-line expressions with side effects, and excessive chaining are to be avoided where possible. When unavoidable, state the intent in a comment
- **Simple flow structure** — Avoid deep nesting; flatten with early returns, guard clauses, and helper-function extraction
- **Single responsibility** — A function performs one clearly defined role
- **No magic values** — Separate Magic Numbers / Magic Strings into named constants or enums
- **Judgment criterion** — Can a teammate seeing this code for the first time understand it without separate explanation?
