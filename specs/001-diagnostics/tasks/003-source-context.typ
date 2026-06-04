= Source Context

== Goal
Add `SourceCode` abstraction that maps byte spans to file or memory context.

== Scope
- source name
- line lookup
- span slicing
- line cache if needed

== Baseline Inputs
- source text examples from tests
- `std.mem` / `std.fs` helpers

== Requirements
- support in-memory source
- support file-backed source later without redesign
- can compute line/column for span

== Tests
- span at start, middle, end
- multiline span frame
- zero-length span
- missing source handling
- line/column math for 1-based user display

== Done
- `src/source.zig` exists
- `SourceCode` exported from `src/lib.zig`
- source lookup tests cover all items in `== Tests`
- `typst compile --features html --format html specs/001-diagnostics/tasks/003-source-context.typ /tmp/source-context.html` passes
