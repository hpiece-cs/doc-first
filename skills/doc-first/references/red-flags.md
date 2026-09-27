# Red Flags

If any rationalization below appears, stop immediately and return to `SKILL.md` §1 Core Principles.

| Rationalization group | In reality |
|---|---|
| Immediate code modification | "Simple change," "quickly," "just one line," and "tests first" are not exceptions. Complete the §1.1 four steps first |
| Skipping documents / INDEX | If a file changes, synchronize `docs/src-notes/` and, when needed, `docs/src-notes/INDEX.md` immediately |
| Approved-scope deviation | Files absent from the document, signature changes, branch additions, and external dependency effects require §1.2: halt → update document → re-confirm → resume |
| Missing subagent context | Code-edit delegation must include the approved document path, approved scope, forbidden scope, and runtime source/drift status |
| Omitting runtime sources | Any value not determined only by function arguments and local constants is not `Data sources: none`; document source type, canonical source, lookup path, shape, fallback, and drift |
| Ignoring drift | If plan/docs/schema/fixture/code disagree, halt coding and document the canonical source. If unclear, do not implement before user confirmation |
| Vague specification writing | "Appropriately," "handles," and prose case lists are forbidden. Write observable behavior as a list, one per line (§4.3.2, the document-wide common rules in `src-note-contract.md`) |
| Over- or under-scaffolding | The table of contents, Overview, Purpose, and Implementation specification are always present; flow diagrams and algorithm sections are present only when their criteria are met. Forcing conditional sections onto a small file, or dropping them when the criteria are met, are both violations (§4.3.1·§4.3.3·§4.3.4) |
| Omitting branches | Every branch point in a function maps 1:1 to one case (or a preparatory branch). Dropping the `otherwise` case, conditions that are not clearly true or false like "if valid," cases without a result, and missing external-call exception propagation all count as omissions (§4.3.2) |
| Source at the project root | Do not place source files directly at the project root. Source always lives under a dedicated folder (§4.1 source tree precondition) |
| Drifting from the reader baseline | The document's reader is a planner or developer seeing this codebase for the first time. Explaining language syntax or general concepts, and conversely omitting domain terms, business rules, or the rationale for a value, are both violations. Writing diagrams and conditions only as code expressions, so that the source must be opened to understand them, is also a violation (§4 reader baseline) |
| Wobbling terminology | Do not spell the same concept differently from place to place. Dense jargon standing alone without its object ("propagated"), abbreviations unexpanded at first appearance, colloquial headings, and words that already carry a different settled meaning in software development are violations too (§4 terminology choice, term selection criteria in `src-note-contract.md`) |
| Scattering algorithms | Procedures of 3 or more steps that compute amounts, permissions, rankings, state transitions, domain policies, or loops/recursion are written once in the algorithm section as `[A-NN]`. Do not scatter them across cases and key constants (§4.3.4) |
| Change-review markup variants | Placing a marker in the middle or at the end of a line, marking a new value with `**…**` alone, or changing the prescribed `classDef` names or review block markers leaves the cleanup script unable to recognize them. Use only the format in the change-review markup rules of `src-note-contract.md` (§4.3.8) |
| Diagram/example mismatch | Steps or branches in the diagram that are not in the code, a terminal-branch count that differs from the case count, restating the same conditions under the diagram, execution examples using real data, and diagrams, reference values, or execution examples left unchanged after a constant changed are all violations (§4.3.3·§4.3.4) |
| ID variants | The only ID prefixes are F/C/E/A. Variants and suffixes such as `E-EDGE-01`, `C-EXC-01`, `E-ERR-01` are forbidden (ID scheme in `src-note-contract.md`) |
| Omitting the implementation specification | The INDEX Specification column, function/case/error IDs, and external integrations must be authored according to the specification-level template (§4.3.5·§4.4) |
| Uncleaned change review | Committing implemented source while the document still has review blocks, 🟢🟠🔴 markers, or `~~old~~ **new**`, deleting only part of them by hand, or skipping the commit check with `--no-verify` is a violation. After the comparison, clean up with `review-clean.sh` and commit the document together. Only work-in-progress commits pass with `[wip]` (§3.2·§4.3.8) |
| Inline-copying shared assets | Content used, or clearly likely to be used, two or more times is extracted into `_shared-*.md` and referenced by link (§5) |
| Subagent exception misconception | Do not skip the skill when called as a subagent. §1.3 takes precedence regardless of execution context |
