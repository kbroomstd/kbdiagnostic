= JSON Serialization

== Goal
Make public data types serializable through Zig `std.json.Stringify` custom hook.

== Scope
- `Severity`
- `SourceSpan`
- `LabeledSpan`
- any other public pure data type that should appear in machine output

== Baseline Inputs
- `pub fn jsonStringify(self: *@This(), jw: anytype) !void` hook from `std.json`
- existing JSON handler requirements

== Requirements
- types serialize without extra adapters
- field names remain stable
- output shape matches `JsonReportHandler` expectations
- no hidden runtime state in serialized types

== Tests
- serialize `Severity`
- serialize `SourceSpan`
- serialize `LabeledSpan`
- compare emitted text against goldens

== Done
- `Severity`, `SourceSpan`, `LabeledSpan` implement `jsonStringify`
- `std.json.Stringify.valueAlloc` tests pass for all three types
- `JsonReportHandler` reuses same field shapes
- `typst compile --features html --format html specs/001-diagnostics/tasks/006-json-serialization.typ /tmp/json-serialization.html` passes
