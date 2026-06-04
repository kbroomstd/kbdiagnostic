= Assertions Helpers

== Goal
Add small assertion helpers for app developers and library tests.

== Scope
- compare spans and labels
- compare diagnostics
- assert rendered output fragments
- assert JSON fields

== Baseline Inputs
- `std.testing.expectXX` naming style
- core diagnostic, span, and handler types

== Requirements
- helper names use `expectXxx` camelCase
- helpers live in `assert.zig`
- helpers stay small and dependency-free
- helpers do not duplicate `std.testing` wholesale

== Tests
- `expectEqualSpan` matches equal spans
- `expectEqualLabel` matches equal labels
- `expectOutputContains` fails when substring missing
- `expectJsonField` finds stable keys in JSON output
- `expectEqualDiagnostic` compares stable public fields

== Done
- `src/assert.zig` exists
- `assert` export exposes `expectEqualSpan`, `expectEqualLabel`, `expectEqualDiagnostic`, `expectOutputContains`, `expectJsonField`
- at least one library test imports `kbdiagnostic.assert`
- `typst compile --features html --format html specs/001-diagnostics/tasks/005-assertions.typ /tmp/assertions.html` passes
