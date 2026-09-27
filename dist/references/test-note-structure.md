# Test Document Structure and Test Seam Exceptions


## Role-first authoring (what / how)

Test documents **lead with the role under test and leave both "what is verified (the src-notes role / case / error being guaranteed)" and "how it is verified (inputs, execution steps, expected outputs, observation method)" together.** Each test item first states the src-notes function/case/error/algorithm ID it guarantees (`[F-NN]` / `[C-NN]` / `[E-NN]` / `[A-NN]`) and the project role that ID carries, then states inputs, execution steps, expected outputs, and observation method. Items that describe only the procedure ("how"), such as "call the function" or "compare the value," are allowed only when the role under verification ("what") is also explicit.
Read this file when entering a test stage or creating `docs/test-notes/` documents. Follow the base location and execution-folder rules in `SKILL.md` §7.

## Test Execution Folder

For each test run, create a date-included folder.

```text
docs/test-notes/<stage>/<YYYYMMDD-test-name>/
  scope.md
  test-items.md
  item-results.md
  test-log.md
```

- The date must include at least `YYYYMMDD`
- The test name briefly identifies the target feature or scope
- Rerun results do not overwrite `item-results.md`; store them as `item-results-run-001.md`, `item-results-run-002.md`, `YYYYMMDD-run.md`, etc.
- Rerun logs also do not overwrite `test-log.md`; store them as `test-log-run-001.md`, `test-log-run-002.md`, `YYYYMMDD-log.md`, etc.

## Required Documents

- `scope.md` — Test scope, target source/functionality, out-of-scope items, preconditions
- `test-items.md` — Test item list, item IDs, inputs/conditions, expected results
- `item-results.md` — Per-item execution results, pass/fail, actual results, failure reason, follow-up actions
- `test-log.md` — Test execution log, execution environment, command, start/end time, exit code, output summary, and paths to raw logs/screenshots/reports

## Test Log

`test-log.md` records **how the test was executed**, not the per-item judgment. Do not mix it with `item-results.md`.

Required fields:

- Executor / execution timestamp / environment (OS, runtime, browser, DB, etc.)
- Base commit or change identifier
- Execution command and key options
- Target test scope and linked `test-items.md` item IDs
- Start time, end time, duration, exit code
- stdout/stderr or test report summary
- Failures, warnings, flaky symptoms
- Paths to raw logs, screenshots, coverage, reports, and other artifacts
- Whether this was a rerun and references to previous log files

## Test Seam Exception

Temporarily modifying implementation source only for tests is prohibited by default. However, if non-destructive methods such as mock/stub, dependency injection, wrapper/adapter, test harness, and public-behavior verification are all impossible and the user approves, add `source-modification-exception.md` and manage the change as an exception.

```text
docs/test-notes/<stage>/<YYYYMMDD-test-name>/
  source-modification-exception.md
```

### Required Exception Document Items

- Exception status: `proposed` / `approved` / `active` / `removed`
- Target test, target source, approver, approval date, removal deadline
- Why each non-destructive method was impossible
- Temporary modification file/location/content
- Whether existing behavior is affected
- Exit condition and removal verification method

### Code Marker

Temporary modification code must include the following marker, and the same ID must be recorded in the exception document.

```text
// [TEST-SEAM:<ID>] remove by <date-or-release>
```

If any of marker, exception document, or removal deadline is missing, treat the change as unapproved.

## Allowed Boundary

Temporary modification is limited to additive changes that do not alter existing behavior. The following are not allowed even under the exception procedure.

- Existing signature/behavior changes
- Visibility relaxation
- Test-detection runtime branches (`if env === "test"`, etc.)
- Weakening validation just to pass tests
