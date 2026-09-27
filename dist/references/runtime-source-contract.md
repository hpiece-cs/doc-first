# Runtime Source and Data Shape Details

Read this file only when the short gate in `SKILL.md` §1.4 and §4.3 is not enough to classify a file. If the file is simply `Data sources: none`, or reads one env var, do not load this whole document; write only a short summary in the Data sources item of the file document's implementation specification.

## Classification Procedure

Before authoring or modifying source code, classify the target file with these questions.

| Question | If yes |
|---|---|
| Is the code determined only by explicit function arguments and local constants? | Mark `Data sources: none` and document only deterministic inputs/outputs |
| Does it read environment variables, config objects, secrets, feature flags, or process settings? | Document configuration source items |
| Does it read or write database rows, object metadata, migrations, schemas, or query results? | Document database/canonical source items |
| Does it read files or generated artifacts? | Document file/artifact source items |
| Does it consume external API responses, webhook payloads, events, queue messages, or cache entries? | Document external contract source items |
| Can the same value come from multiple sources? | Add a precedence/fallback table |
| Do plan, spec, schema, fixture, docs, and existing code disagree? | Halt coding and follow Drift handling |

## Minimal Table

Most files only need this one table.

| Source type | Canonical source | Runtime lookup path | Shape | Fallback | Drift |
|---|---|---|---|---|---|
| none / configuration / database / file / external contract / cache / event / generated artifact / other | Where the value or shape is officially defined | env var, config key, table/column, file path, endpoint, event name, cache key, topic, etc. | schema, field, enum, nullability, unit, limits | order and exact condition for moving to the next source | none / known mismatch / unresolved |

When needed, add owner, loading method, refresh timing, and verification method as short lines in the same section.

## Source-Specific Additions

### Configuration Source

Applies to files that read environment variables, config objects, secrets, feature flags, or process settings.

- key name, required/optional status, default value
- actor that injects the value
- local/test/production source differences
- missing or invalid value handling
- whether the file reads a file directly or only reads process/runtime state already loaded

### Database / Canonical Source

Applies to files that read or write persistent records, schema-defined fields, migrations, or query results.

- canonical schema or contract location
- table/entity/field name or storage key
- query or lookup condition
- expected row count/cardinality
- behavior when the row is absent
- field shape and type conversion
- writer/owner
- whether schema change is in the current work scope

### File / Artifact Source

Applies to files that read local files, uploaded files, generated artifacts, manifests, or serialized inputs.

- path or resolver
- file format, encoding
- required field or section
- behavior when the file is absent
- behavior when the shape is invalid
- generator or updater

### External Contract Source

Applies to files that consume API responses, webhook payloads, queue messages, events, cache entries, provider responses, or service-to-service contracts.

- producer/owner
- endpoint/topic/event/cache key or lookup
- payload shape and version
- required/optional fields
- compatibility policy for extra or missing fields
- retry/failure semantics

## Drift Handling

If a source or shape mismatch is found, halt before modifying source code.

Drift examples:

- plan and schema disagree
- code reads a different key than the document
- fixture shape differs from the production contract
- fallback order differs across documents
- writer/owner is unclear
- there is no way to verify the runtime source

Procedure:

1. Record the mismatch in the related `docs/src-notes/` document
2. Identify candidate canonical sources
3. If the canonical source is clear, document the decision and proceed only after user confirmation
4. If the canonical source is unclear, ask the user before coding
5. Add or update tests for the selected source shape and fallback behavior

## Test Linkage

If a file document defines runtime source, data shape, precedence, or fallback behavior, the related test plan includes these cases.

- canonical source success
- fallback path, if present
- missing source
- malformed or incompatible shape
- precedence order when multiple sources exist at the same time
