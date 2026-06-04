= Std Compat

== Goal
Match useful std hooks beyond JSON and format.

== Scope
- `eql` on pure value types
- `hash` only where cache/map use is justified
- `clone` only on owned container types if added later

== Baseline Inputs
- `std.meta.eql`
- `std.hash_map` context patterns
- current data types

== Requirements
- `Severity`, `SourceSpan`, `LabeledSpan` compare cleanly with `std.meta.eql`
- hash support only if type is used as cache key
- no unnecessary clone API on cheap value types
- no runtime wrapper participates in map-key protocol by default

== Tests
- `std.meta.eql` on equal and unequal spans
- `std.meta.eql` on equal and unequal labels
- `std.meta.eql` on severities
- hash helper, if added, collides only on equal values

== Done
- `std.meta.eql` passes for `Severity`, `SourceSpan`, `LabeledSpan`
- `hash` is either absent or documented with one exact use-case
- runtime wrappers expose no `clone`/`hash` protocol by default
- `typst compile --features html --format html specs/001-diagnostics/tasks/008-std-compat.typ /tmp/std-compat.html` passes
