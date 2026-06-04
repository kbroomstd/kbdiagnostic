= Core Model

== Goal
Define `Severity`, `LabeledSpan`, `SourceSpan`, and diagnostic trait contract with stable tests.

== Scope
- value types
- trait defaults
- ownership rules
- basic validation

== Baseline Inputs
- current `src/root.zig`
- Zig std refs under `.references/codeberg.org/ziglang/zig`

== Requirements
- `Diagnostic` exposes code/help/url/source_code/labels/related/diagnostic_source
- `LabeledSpan` can carry span, optional label, primary flag
- `Severity` covers at least Advice, Warning, Error
- default trait methods return `null` / none

== Tests
- mock diagnostic with all metadata hooks returning values
- default trait methods return none
- construct labeled span variants
- round-trip severity defaults
- related diagnostic iterator preserves order

== Done
- `src/severity.zig`, `src/span.zig`, `src/diagnostic.zig` exist
- `Severity`, `SourceSpan`, `LabeledSpan`, `Diagnostic` exported from `src/lib.zig`
- unit tests cover all items in `== Tests`
- `typst compile --features html --format html specs/001-diagnostics/tasks/001-core-model.typ /tmp/core-model.html` passes
