---
name: doc-first
description: Use when modifying, implementing, refactoring, or creating source code — triggers on requests like "구현해줘", "코드 수정", "리팩토링", "버그 수정", "기능 추가", "이 함수 바꿔줘", "implement", "fix bug", "add feature", "refactor", or any task that will write/edit source files in a project. Enforces document-first workflow requiring `docs/src-notes/` documentation and user review BEFORE any code changes, and approved-scope-only execution that pauses on scope deviation. Skip for read-only questions, code exploration, or pure documentation/test edits.
---

> **Language policy:** Respond in the user's language.
> - Detect the user's language from their most recent message and reply in that language.
> - If the user mixes languages, follow the dominant language of the latest message.
> - Korean message → reply in Korean. English → English. Japanese → Japanese. Etc.
> - Document file content (`docs/src-notes/`, `docs/spec-notes/`, etc.) follows the project's existing language convention. If no precedent exists, ask the user once which language to use, then keep consistent.
> - Section headings and templates inside this skill (e.g., "Scope & logic outline") are in English in this distribution build; translate them when communicating with users in other languages.

# Implementation Stage Rules (Document-First)

## Conditional Detailed References

Read these files only under the matching condition. Otherwise, follow the main body rules.

- When authoring/modifying file-level documents: `references/src-note-contract.md` (completed example: `references/src-note-example.md`)
- When creating or cleaning up a change-review document for modifying existing source: the change-review markup rules in `references/src-note-contract.md` (completed example: `references/src-note-review-example.md`)
- When an example for `docs/src-notes/INDEX.md` is needed: `references/src-index-example.md`
- When runtime sources include multiple sources, fallback, external contracts, DB/schema, drift, or ambiguous classification: `references/runtime-source-contract.md`
- When creating a test execution folder or test seam exception: `references/test-note-structure.md`
- When entering actual source implementation after approval: `references/code-authoring.md`
- When rationalization, scope deviation, or skipped procedure seems possible: `references/red-flags.md`

## 1. Core Principles

> The top-level principle that applies **without exception** to every code implementation and modification task.
> The detailed rules in §2–§8 below support this principle; in case of conflict, this principle takes precedence.

### 1.1 Document-First Principle

**Even when a prompt requests a code change, you must NOT modify source code immediately.**

Every code task MUST follow these four steps:

1. **Scope & logic outline** — Specify which files, which ranges, and which logic will change
2. **Document pre-reflection** — Reflect the outlined content into the relevant `docs/src-notes/` document first
3. **User confirmation** — Show the updated document to the user and obtain confirmation
4. **Proceed after document review** — Only after confirmation may actual source code modification proceed

**Skipping any one of these four steps violates this principle.**

There is no exception even when the prompt asks for an urgent change or the user says "quickly," "simple," or "just one line." Regardless of urgency, size, or obviousness, complete the four steps above first.

### 1.2 Approved-Scope-Only Principle

**Implement only the scope that was approved in review.** If, during implementation, a change outside the approved scope becomes necessary:

1. **Halt immediately** — Stop writing code at once
2. **Update the document** — Reflect the additional scope/logic into `docs/src-notes/` (and into `docs/spec-notes/` · `docs/flow-notes/` if needed)
3. **Re-confirm** — Re-confirm with the user using the updated document
4. **Resume** — Resume implementation only within the re-confirmed scope

#### 1.2.1 Scope deviation criteria (any one triggers §1.2)

- Creating or modifying files/folders not present in the document
- Changing function/variable signatures (inputs/outputs, types, exceptions)
- Adding, deleting, or changing control flow or branch cases
- Changes that affect `docs/spec-notes/`, `docs/flow-notes/`, or external dependencies

#### 1.2.2 Exception (no halt required)

Behavior-neutral changes such as typos, formatting, and comment cleanup do not require halting and are synchronized after the fact (§3.2 ⑤). However, the moment such changes accumulate to affect behavior, switch to the §1.2 procedure.

### 1.3 Subagent-Inclusive Principle

**This rule applies with priority regardless of execution context.** Whether executed via Task/Agent tools, parallel agents, Gemini extensions, OpenCode commands, or any other subagent path, §1.1 and §1.2 apply identically.

- doc-first takes precedence over other skills' `<SUBAGENT-STOP>` guidance
- The main agent must complete the §1.1 four-step procedure before delegating code editing
- The main agent must include the approved `docs/src-notes/` document path, approved scope, forbidden scope, and runtime source/drift status in the delegation prompt
- The subagent must re-affirm this rule on entry and apply §1.2 scope-deviation criteria even inside the delegated scope
- If the subagent finds an unapproved file change, signature change, branch addition, runtime source/drift mismatch, or required document update, it reports a halt to the main agent instead of coding

### 1.4 Runtime Source Gate

Before authoring or modifying a source file, classify whether the file is determined only by explicit function arguments and local constants.

- Yes: write `Data sources: none` in the file document's implementation specification and document only deterministic inputs/outputs
- No: the Data sources item of the file document's implementation specification must include a runtime-source summary
- If sources are multiple, fallback exists, or plan/docs/schema/fixture/code disagree, halt coding and read `references/runtime-source-contract.md`
- Do not implement until the user confirms when the canonical source is unclear

---

## 2. Document System Overview

| Directory | Role | When to author / update |
|---|---|---|
| `docs/spec-notes/` | **Standard specs / guidelines** that serve as the implementation baseline, and **shared assets** referenced by two or more documents | Immediately upon deriving a standard/guideline or identifying a shared asset |
| `docs/src-notes/` | **Folder/file-level pre-implementation documents** | Immediately before actual code implementation |
| `docs/flow-notes/` | **Structural-perspective documents** for major feature flows, system architecture, data/event flows, etc. | When major flows/structures are newly created or changed |
| `docs/test-notes/` | Functional test **plans, cases, results, and verification guides** | Upon entering the test stage (by stage and by run) |

Each directory has a non-overlapping role.

---

## 3. Implementation & Modification Procedure

### 3.1 New implementation

1. **Verify standards/guidelines** — Check relevant `docs/spec-notes/` documents first and use them as the implementation baseline
2. **Author the pre-implementation document** — Write folder/file-level documents in `docs/src-notes/` per §4 conventions, and for new files add an entry to `docs/src-notes/INDEX.md` (§4.4)
3. **User confirmation (review)** — Review the authored document and obtain confirmation
4. **Code implementation** — Implement actual source code only after review completes
5. **Handling scope deviation** — Per §1.2, halt immediately → re-approve → resume
6. **Reflect flow/structure** — When major features/structures are newly created or changed, reflect into `docs/flow-notes/`

### 3.2 Modifying existing source

1. **Check the existing document** — First check the relevant `docs/src-notes/` sub-document for the source being modified
2. **Scope & logic outline** — Identify which document items/IDs the change connects to and which file ranges will change
3. **Document pre-reflection and user confirmation** — Even when the change matches the existing document, reflect the change scope and logic into `docs/src-notes/` first and obtain user confirmation. **Rewrite the body to its post-change form** and mark the change locations with change-review markup (§4.3.8). If the file summary, role, or specification level changes, update `docs/src-notes/INDEX.md` as well (§4.4)
4. **Modify code after review** — Only after confirmation, modify actual source within the approved scope
5. **Compare implementation results** — After code modification, confirm the document and implementation match 1:1; only behavior-neutral typos, formatting, and comment cleanup are synchronized after the fact (§1.2.2)
6. **Document refresh** — Once the comparison is done, clean up the change-review markup so the document becomes the current source guide. Do not delete it by hand; run the cleanup script (`review-clean.sh <document>`) and check the result. Include the cleaned document in the source commit

**Commit check** — In a doc-first project, the git `commit-msg` hook aborts the commit if change-review markup remains in the document (per INDEX.md) of any source included in the commit. If it aborts, finish steps 5 and 6 and commit again. Only work-in-progress commits made mid-implementation may pass by including `[wip]` in the commit message. Do not skip the check with `--no-verify`.

**Commit check hook installation** — In Claude Code, the session start hook installs it automatically. In tools without automatic installation (Codex, Copilot, Gemini CLI, OpenCode, etc.), run `install-git-hook.sh` at the start of work if `.git/hooks/commit-msg` has no `doc-first-commit-check` marker, and tell the user that `install.sh --git-hooks=<folder>` installs it into many repositories at once. Projects that manage the hook path as repository files (husky, etc.) are not installed automatically, so relay the connection method shown to the user. The script location is `${XDG_DATA_HOME:-~/.local/share}/doc-first/bin/`.

**Commit check limits** — The check runs only as a git hook on each machine. It cannot stop commits made with `--no-verify` or on machines where the hook is not installed. No server-side check is provided.

---

## 4. Pre-implementation Document Authoring Convention (`docs/src-notes/`)

> **Reader baseline (applies to both §4.2 and §4.3)**
>
> The reader of every `docs/src-notes/` document is a **planner or developer seeing this codebase for the first time** — someone who understands the service's features and business rules and is comfortable with development terminology, but does not know this project's code. Before opening the source, this reader must be able to grasp and review the features, flows, and rules from the document alone. Even if an AI writes the document, a person reads it. This baseline decides what to write and what to leave out.
>
> - **Do not write** — language syntax, standard library, data structures, and general concepts such as try/catch, async, or dependency injection. The reader already knows them. Spend no lines on knowledge a search would return
> - **Always write** — this project's domain terms and business rules, why this value is this value, why this order, and which cases are deliberately not handled. What the reader does not know is not code, it is **this project**
> - **The test** — write what can only be learned by reading this repository; leave out what can be learned anywhere else
>
> **Terminology choice**
>
> Use terminology that matches the project's nature, but the reader above must get through it without a dictionary. The style is declarative technical-document prose ("does X"); do not use a colloquial style.
>
> - **Use one spelling per concept across the whole document.** Writing "propagated as-is" in one place and "propagated" in another makes the reader assume two different behaviors
> - **Prefer wording that shows the behavior over dense jargon.** Even an established term blurs when it stands alone without its object — write "exception propagated as-is," not "propagated"
> - **Name section headings and item labels with terms that are standard in design and specification documents, and fit the name exactly to the scope of its content.** Do not use casual or colloquial wording, words that already carry a different settled meaning in software development, or terms that only make sense to readers who know a particular theory. The five criteria and examples live under **Term selection criteria** in `references/src-note-contract.md`
> - Domain-term usage, reuse of established expressions, abbreviation expansion, and keeping code identifiers verbatim live in `references/src-note-contract.md`
>
> **Role-first description (what / how):** When describing a folder, file, class, function, or public constant, **write "what it does (project role / result)" first and "how it does it (implementation method)" after.** Expressions that state only the implementation, such as "passes to a handler" or "puts into a queue," are allowed only when the role and result appear too. The sentence structure and the good/bad examples live in `references/src-note-contract.md`.

### 4.1 Authoring Unit & Filename Rule

- **Source root list** — State the source roots subject to documentation at the top of `docs/src-notes/INDEX.md`. A single project usually uses one of `src/`, `lib/`, or `app/`; projects with monorepos or framework conventions may state multiple roots such as `packages/<pkg>/src/` and `apps/<app>/src/`. If source under an unstated root must be modified, treat it as a §1.2 scope deviation and update INDEX.md first. When roots overlap (`src/main/java/` and `src/main/java/com/example/shop/`), the longer root applies.
- **Base package** — A root may carry the package name the project declares in its configuration. The format is `- <root path> — base package <name>`. For a root with a base package, **that name is the level-1 directory** and the root path's segments are not counted. Boilerplate prefixes such as `src/main/java/com/example/shop/` therefore disappear from the document path.
  - The name comes from project configuration: for Java/Kotlin the base package (the package of the Spring Boot `@SpringBootApplication` class, the Android `namespace`), for Python the distribution package name (`pyproject.toml`), for C# the `RootNamespace`, for Swift the target name, for Rust the crate name. The AI does not infer or choose the name
  - In languages where the package path appears in the source path (Java, Kotlin, Python), state the root **down to the base package folder** (`src/main/java/com/example/shop/`). Where it does not (C#, Swift, Rust), state the source folder (`src/Shop.Order/`)
  - The name is a single segment without `/`. Names containing `/`, such as npm scoped names (`@shop/api`), are not declared
  - In multi-module projects, state one line per module with its root and base package. If several roots declare the same base package, their documents share the same level-1 directory (`src/main/java` and `src/main/kotlin` using one package)
  - Files outside the base package (`src/main/java/module-info.java`) get a separate root without a base package (`src/main/java/`) and follow that root's rule
  - A root without a declaration counts segments from the root path as below. Document paths of existing projects do not change
- **Source tree precondition** — Do not place source files directly at the project root. All source resides under a **dedicated source folder** (`src/`, `lib/`, `app/`, `packages/<pkg>/src/`, etc.; the name is free). There may be several roots, but every one is stated in INDEX.md. If this precondition breaks, level counting loses its basis and path mapping becomes unstable.
- Organize **folder-level** and **file-level** documents as separate Markdown files
- **Document path rule — four-level mirroring + path flattening.** The document path is derived mechanically from the source path in the order below. There is no room for judgment.
  1. **Counting levels** — One source path segment is one level. `src/`=1, `src/services/`=2, `src/services/auth/`=3, `.../oauth/`=4. If the root has multiple segments such as `packages/api/src/`, count each separately (`packages/`=1, `packages/api/`=2, `packages/api/src/`=3). If the root declares a base package, **the base package name is level 1** instead of the root path, and the first segment under the root is level 2 (`com.example.shop/`=1, `.../order/`=2, `.../order/service/`=3).
  2. **Keep levels 1–4 as directories** — Mirror the source path as real directories. Depth under `docs/src-notes/` is at most 4.
  3. **Flatten from level 5** — Take the **remaining relative path from the level-4 directory** (level-5-and-deeper segments only), replace `/` with `__`, and use it as the filename inside the level-4 directory. Levels 1–4 are not in the filename.
  4. **File document** — Keep the source filename **including its extension** and append `.md` (`login.ts` → `login.ts.md`). If folders end before level 4, place the file in that level's directory.
  5. **Folder document** — Apply rules 1–3 to the folder path and append `.md`. A folder kept as a directory gets a `.md` of **the same name, side by side**.

  | Source | Document (relative to `docs/src-notes/`) |
  |---|---|
  | Folder `src/services/auth/oauth/` (level 4) | `src/services/auth/oauth.md` |
  | File `src/services/auth/oauth/google.ts` | `src/services/auth/oauth/google.ts.md` |
  | File `src/services/auth/oauth/providers/github.ts` (level 5 → flattened) | `src/services/auth/oauth/providers__github.ts.md` |
  | File `packages/api/src/services/auth/login.ts` (root is level 3) | `packages/api/src/services/auth__login.ts.md` |
  | File `src/main/java/com/example/shop/order/service/OrderService.java` (root `src/main/java/com/example/shop/`, base package `com.example.shop` → level 1) | `com.example.shop/order/service/OrderService.java.md` |
  | File `src/main/java/com/example/shop/order/service/impl/dto/Line.java` (level 5 → flattened) | `com.example.shop/order/service/impl/dto__Line.java.md` |
  | Folder `src/main/java/com/example/shop/order/service/` (level 3) | `com.example.shop/order/service.md` |

  The full level-by-level mapping table lives in `references/src-index-example.md`.

- All pre-implementation documents are stored only at the `docs/src-notes/` subpath determined by the rule above. Other locations or names are forbidden

### 4.2 Folder-level document items

- **Sub-composition summary** — Briefly define the function of each sub-folder and file
- **Folder-internal feature flow (Flow)** — Operational flow separated by normal / exception / branch cases

### 4.3 File-level document items (Source guide + implementation specification)

A file-level document is **the guide to that source file**. The §4 reader must be able to grasp, from the document alone, what the file does and why, and what each function returns in which order and under which conditions. The opening part (Overview, Purpose) gives the whole picture, the function sections carry the flow and the cases, and the closing implementation specification carries the specification used for verification. At the same time, the case IDs and the implementation specification must make two kinds of verification possible.

1. **Pre-check (detecting implementation omissions)** — The number of branch points per function and the number of cases can be compared 1:1 to find what is missing
2. **Post-check (verifying implementation correctness)** — The cases become the test cases, so behavior can be confirmed

#### 4.3.1 Document structure

Keep the order below. Function sections list public functions first, then internal functions. Flow diagrams and algorithm sections are conditional (§4.3.3·§4.3.4); when the criteria are not met, do not include them. The table of contents, Overview, Purpose, and Implementation specification are always present.

```markdown
# <source path>

**Table of contents**
- [Overview](#overview)
- [Purpose](#purpose)
- [Usage example](#usage-example)
- [F-NN] [<function name>](#<anchor>) — <one-line role>
- [A-NN] [<algorithm name>](#<anchor>) — <one-line rule summary>
- [Implementation specification](#implementation-specification) — <sub-items it contains>

## Overview
- **Function** — <the behavior this file enables in the product>
- **Invocation** — <who or what calls it, and when>
- **Result** — <result on success and on failure>        ← when there is a return value or side effect
- **Key rule** — <one-sentence domain rule, with actual values> [A-NN]  ← only when present
- **Specification level** — minimal | standard | full

## Purpose
<why this file is needed and why it works this way. One sentence per line>

## Usage example
<code block — mandatory if there is a public function>

## [F-NN] <function name>
<one or two sentences on its role>
<flow diagram — conditional §4.3.3>  or  <case list>
**Step notes** / **Boundary conditions** / **Common exceptions**   ← only when present
**Out of scope**                                                 ← standard and above

## [F-NN] <internal function name> (internal function)
<role — including the outcome this function produces>. Case list or see [A-NN]

## [A-NN] <algorithm name>                          ← conditional §4.3.4
**Rule** / **Rule rationale** / processing diagram / reference values / **Step notes** / **Execution example** / **Boundary conditions**

## Implementation specification                     ← mandatory §4.3.5
**Data sources** / **Public interface** / **Key constants and fields** / **Errors and exceptions** / **External integrations**
```

- **If there is no public function**, omit the Usage example section and its table-of-contents entry
- **Presentation format** — use a table only when several items must be compared side by side on the same columns (execution examples, output schema). Otherwise write a line-broken list. A list item puts the core (condition → result, name = value) on its first line and examples or notes on the indented next line
- **ID position** — In headings, the table of contents, and case lines, the item's own ID (`[F-NN]`, `[A-NN]`, `[C-NN]`) goes **first**. The ID then always sits in the same column regardless of the length of the name or sentence, so it is easy to scan for. Reference IDs pointing at other items (`→ [E-NN]`, `see [A-NN]`) stay inside the sentence
- **Where reasons go** — reasons for an order, value, or approach are not collected separately; they go in that step's note or directly under the relevant item

#### 4.3.2 Cases — no omissions

A case defines, one at a time, which result a function produces under which condition. There are two notations.

- **Function with a flow diagram** — the diagram is the case definition. Each branch leading into a terminal node is one case, and its branch label is prefixed with `C-NN`. Do not restate the same conditions as a list under the diagram
- **Function without a flow diagram** — write a list. `- [C-NN] <condition> → <result>`, with the example on the indented next line as `e.g. <input> → <output>`
- **Condition** — write a sentence that is clearly true or false, and write reference values as actual values (`60 minutes or more have passed`). "If valid," "when needed," and "handles" are forbidden
- **Result** — one or more of: a return value, an error (`E-NN` + error code), an exception propagated as-is (`E-NN`), or applying an algorithm (`A-NN`)
- **IDs** — `[C-NN]` and `[E-NN]` are **numbered sequentially across the whole file**. Do not restart at 01 per function. External exceptions propagated without catching also receive an `[E-NN]`
- **Branch 1:1** — every branch point in the function (if/else, switch, early return, loop exit, try/catch, ternary, null coalescing) corresponds to one case. The else/default branch is a case too. Propagating an external call's exception without catching it is also one case (**Common exceptions**). Present only in code = document omission; present only in the document = implementation omission
- **Preparatory branches** — a branch that does not split the result and rejoins the next step directly (value normalization, filling a default) is not counted as a case. Write it as one line in that step's note, and count it separately as a preparatory branch during branch reconciliation
- **Branches inside algorithms** — branches inside an algorithm separated as `[A-NN]` are written in the algorithm section, and the case points to it as `apply A-NN`. Branch reconciliation counts cases and the algorithm section together
- **Format detail lives in the reference** — condition wording, case order, boundary conditions, out of scope, and value notation are owned by `references/src-note-contract.md`

#### 4.3.3 Flow diagram — conditional

If **any one** of the following applies to a function, put a Mermaid flow diagram in that function's section. If none applies, write a case list.

- It has 4 or more cases
- The order of judgments changes the result (an earlier judgment is a precondition of a later one)
- Branches rejoin or there is a loop

Place the diagram directly under the role description of the function section. A decision node is **a number + a question answerable with yes or no** (`③ Locked now?`), and a branch label is `Yes`/`No` or an actual value (`60 min or more`). Do not put code identifiers, function calls, or code expressions in the diagram; they go in the implementation specification. Ordering reasons, boundary conditions, and side notes that the diagram cannot hold go in **Step notes** under the diagram, keyed by step number. Label syntax, line length, the size limit, and the alternatives for cases where a diagram does not fit follow the diagram rules in `references/src-note-contract.md`.

#### 4.3.4 Algorithm section — conditional

If the procedure has **3 or more steps**, **changes state or a value through calculation**, and matches one of the following, an algorithm section is mandatory. Simple fallback chains and simple mappings are excluded because cases suffice. If nothing qualifies, do not include the section.

- The calculation result determines an amount, quantity, permission, ranking, or state transition
- It implements a domain policy or rule (settlement, discount, retry, lockout, expiry, etc.)
- It operates as a loop, recursion, or state machine

Give each algorithm its own `## [A-NN] <name>` section and write **Rule**, **Rule rationale**, a processing diagram (a numbered procedure if there are no branches), a reference-values line, **Step notes**, an **Execution example** table, and **Boundary conditions**, in that order. **Rule** states the domain rule this algorithm creates in plain prose with actual values, so that reading it alone tells you what happens to the user without reading the procedure. The authoring rules for each item are owned by `references/src-note-contract.md`.

#### 4.3.5 Implementation specification and specification levels

`## Implementation specification` is always present. It is the specification used for verification: it sets out what this file exchanges with the outside and which boundaries it must not cross. If the implementation departs from the public interface, errors, or external integrations written here, that is a §1.2 scope deviation.

The first item is **Data sources**, the place to record the runtime source. If behavior is determined solely by explicit function arguments and local constants, write `Data sources: none`; if a branch depends on a value read through an external call (DB record, configuration, environment variable, browser API), it is not `none`. The notation, multiple sources, drift, and ambiguous classification are owned by `references/runtime-source-contract.md`.

Choose one of the three specification levels per file and record it in the Overview and in the §4.4 `INDEX.md` Specification column (no arbitrary AI judgment). Cases and IDs, enumeration, and verifiable expression are **common to every level**.

| Level | Mandatory items in the implementation specification | Suitable code |
|---|---|---|
| `minimal` | Data sources, public interface (including constants) | Simple helpers, single-responsibility utilities, thin CRUD wrappers |
| `standard` | minimal + key constants and fields, errors and exceptions, external integrations, Out of scope in function sections | General business logic (default) |
| `full` | standard + output schema, pre/postconditions and invariants, test traceability | Authentication, payment, consistency, authorization, billing |

- **Explaining what a value does**: a constant or field that governs a branch states **what it decides and what happens when it is met**. An item carrying only a name and a value is incomplete (authoring rules and examples: `references/src-note-contract.md`)
- **Default**: `standard` if unspecified. Leave a short justification when choosing `minimal` or `full`
- **Level change**: apply the §1.1 four steps and update the INDEX.md column together
- **Length**: include conditional sections (flow diagrams, algorithms) only when their criteria are met. Do not wrap a small file in a large skeleton

#### 4.3.6 Detailed rules and examples

The detailed format of cases, flow diagrams, algorithms, and implementation specification items, as well as the term selection criteria, follows `references/src-note-contract.md`. For completed forms, `references/src-note-example.md` has two examples: a large file (`standard`) and a small file (`minimal`).

#### 4.3.7 Authoring flow

1. Select the level → record it in the INDEX.md Specification column
2. Write the Overview and Purpose
3. For each function, write the role description → decide on a flow diagram (§4.3.3) → write the diagram or the case list
4. Decide on algorithm sections (§4.3.4) → write them if applicable
5. Write the implementation specification
6. Write the table of contents — a one-line role for each function and algorithm entry
7. **Branch reconciliation** — per function, branch points in the code (or the design, if new) = cases + preparatory branches + branches in the algorithm section. If there is a diagram, branches into terminal nodes = case count, and confirm it renders. Confirm every [E-NN] in Errors and exceptions is referenced from a case
8. User review via the §1.1 four steps → implement only after it passes. Every subsequent change is tracked 1:1 against IDs

#### 4.3.8 Change-review markup — when modifying existing source

When modifying existing source, a single file document serves both the pre-change review and the post-change refresh. Rewrite the body to its **post-change form**; information needed only during review is attached using the prescribed markup and removed by the cleanup script after implementation. Git holds the change history, so it is not kept in the document.

- **Review block** — Content that exists only during review goes between the `🔍 **Review block start**` line and the `🔍 **Review block end**` line. Both marker lines stay visible, so reviewers can see which content is temporary and will be removed after implementation. This holds the **review notice and marker legend** under the title, the **Change review** section under the table of contents, the **change summary** at the head of each section, and the **change comparison** diagram for a flow whose structure changes. Put a blank line before and after each marker line
- **Change review** — Number only the behaviors that actually change, as **Change N**. For each change write **Current** (how it behaves now) → **After** (how it will behave) → **Reason** → **Affected sections** (links to sections revised because of it), so that someone who does not know the current code can see what changes and how. Places revised as a consequence of a change, such as added constants, fields, or errors in the implementation specification, are affected sections, not changes. Then write the impact outside this file and the review questions
- **Line marker** — 🟢 added, 🟠 changed, 🔴 removed. The marker shows what happened to the line; the change number shows why. In the table of contents, put the marker at the very start of each affected section's line and append ` — change N·N` to the end of the line
- **Value markup** — a changed value is `~~old~~ **new**`; words newly inserted into a line are `<ins>…</ins>`
- **Diagram** — When a decision step is added, removed, or moved, put a comparison diagram in the review block that places only the changed segment side by side as `Current` and `After`, and draw the whole post-change flow in the main diagram. When only a value changes, skip the comparison diagram; color the node in the main diagram and append `<br/>current <old value>` to the end of its label
- **Cleanup** — After comparing implementation results (§3.2 step 5), use `review-clean.sh` to remove the review blocks, markers, old values, and diagram color assignments

The exact markup format is defined in the **Change-Review Markup Rules** of `references/src-note-contract.md`, and the completed form is in `references/src-note-review-example.md`. The cleanup script recognizes only this format, so do not use markers of any other shape.

### 4.4 Project Source Index (`docs/src-notes/INDEX.md`)

Maintain a **single index file** at `docs/src-notes/INDEX.md` that lets you survey all source files in the project at a glance.

- **Location** — `docs/src-notes/INDEX.md` (fixed; no alternative path allowed)
- **Format** — Source root list and Markdown table (`| source path | one-line summary | document | specification |`)
- **Source root list** — State the documentation target roots at the top of INDEX.md under `Source roots` or an equivalent heading
- **Row unit** — File-level. Folders are not included in the table; use headings (`##`) only for sorting/grouping
- **Document link** — Link to the document path derived by the §4.1 rule, relative to `INDEX.md` (`[doc](src/services/auth/login.ts.md)`)
- **Specification column** — Mark each file's §4.3.5 specification level as one of `minimal` / `standard` / `full`. Omission is forbidden (every row must carry a value; even when the default `standard` applies, write it explicitly). The purpose of this column is to expose the level deterministically so that the AI does not judge it ad hoc
- **Update triggers** — Update immediately when a file is created, deleted, moved, or renamed; when source roots change; when the function description in the Overview changes; when a refactor changes the file's responsibility; or when the specification level changes
- **Update procedure** — Part of the document pre-reflection step of the §1.1 four-step procedure. After modifying the file-level document, update INDEX.md too and obtain user confirmation

The format example and the path mapping table are owned by `references/src-index-example.md`.

---

## 5. Standard Spec & Shared Asset Management (`docs/spec-notes/`)

- **Targets**
  - Standard specs/guidelines that serve as implementation baselines (API specs, protocols, coding conventions, domain standards, external system interfaces)
  - Assets commonly referenced by two or more `docs/src-notes/` documents (snippets, tables, metric definitions, enum value lists, etc.)
- **Filename rules**
  - Standard spec: `<topic>.md` or `spec-<topic>.md`
  - Shared asset: `_shared-<topic>.md` (e.g., `_shared-error-matrix.md`, `_shared-proto-enums.md`)
- **Reference method** — Inline copying is forbidden in `docs/src-notes/` documents; reference by link only — `[Spec document](../spec-notes/xxx.md)`
- **Application criteria**
  - Standard spec: Organize immediately upon deriving a new standard/guideline; all subsequent implementation proceeds against it
  - Shared asset: Extract immediately when identical content appears (or is clearly going to appear) in two or more documents

---

## 6. Flow & Structure Document Management (`docs/flow-notes/`)

- **Targets**
  - Operational flows of major features (workflows, sequences, state transitions)
  - Structure/architecture of the overall system or among major components
  - Data flows, event flows, call relationships
- **Role separation** — Do not duplicate `docs/src-notes/` (file-level) or `docs/test-notes/` (tests). This location is **for the flow/structure perspective only**

---

## 7. Test Document Management (`docs/test-notes/`)

> **Role-first authoring:** Each test item first states the src-notes ID it guarantees (`[F-NN]` / `[C-NN]` / `[E-NN]` / `[A-NN]`) and that ID's role, then inputs, steps, and expected outputs. The authoring rules are owned by `references/test-note-structure.md`.

- **Per-stage subdirectory** — `unit/`, `integration/`, `system/`, `acceptance/`, etc., in the form `docs/test-notes/<stage>/`
- **Test execution folder** — For each test run, create a date-included folder such as `docs/test-notes/<stage>/<YYYYMMDD-test-name>/`
- **Required document separation** — Create `scope.md`, `test-items.md`, `item-results.md`, and `test-log.md` separately inside the test execution folder; store rerun results and logs as separate files
- **Test seam exception management** — Temporarily modifying implementation source only for tests is prohibited. The exception conditions and procedure are owned by `references/test-note-structure.md`
- **Runtime source test linkage** — When runtime sources, fallback, or precedence are documented, the related test plan includes success, missing-source, invalid-shape, and precedence cases
- When entering a test stage, read `references/test-note-structure.md` for the detailed structure and required exception items

---

## 8. Post-Approval Code Authoring Principles

After the §1.1 document review and user confirmation are complete, implement source as code in a form easy for a human to understand. When entering actual implementation, read `references/code-authoring.md`.

---

## Red Flags — Stop immediately and return to §1 Core Principles

Skipping procedure, skipping documents/INDEX, omitting runtime sources, ignoring drift, approved-scope deviation, vague specification, omitting cases / branches / algorithms, omitting the implementation specification, inline-copying shared assets, and subagent exception misconceptions all violate this principle. When in doubt, read `references/red-flags.md` and return to the §1 procedure.
