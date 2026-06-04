= Format Hooks

== Goal
Make public data types printable through Zig `std.fmt` custom hook.

== Scope
- `Severity`
- `SourceSpan`
- `LabeledSpan`
- any other public pure data type used in debug logs

== Baseline Inputs
- `pub fn format(self: T, writer: *std.Io.Writer) std.Io.Writer.Error!void` hook from std
- existing assertion helpers and JSON serialization shape

== Requirements
- types format without extra adapters
- text output is stable and short
- output shape useful in logs and test failures
- no hidden runtime state in formatted types

== Tests
- format `Severity`
- format `SourceSpan`
- format `LabeledSpan`
- compare emitted text against goldens

== Done
- `Severity`, `SourceSpan`, `LabeledSpan` implement `format`
- `std.fmt` fixture tests pass for all three types
- assertion helpers can reuse same text representation
- `typst compile --features html --format html specs/001-diagnostics/tasks/007-format-hooks.typ /tmp/format-hooks.html` passes
