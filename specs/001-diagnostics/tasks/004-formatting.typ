= Formatting

== Goal
Render human-readable diagnostics with clear visual hierarchy.

== Scope
- headline
- labeled spans
- notes
- help
- color fallback

== Baseline Inputs
- completed core model
- completed source context
- renderer interface

== Requirements
- readable without ANSI
- stable line wrapping rules
- single diagnostic output deterministic in tests

== Tests
- golden output for colored mode
- golden output for plain mode
- no crash on missing labels
- headline order stable
- code / help / url placement stable

== Done
- `src/handlers/graphical.zig` exists
- `GraphicalReportHandler` export renders all fixture cases in `== Tests`
- snapshot tests cover colored and plain output
- `typst compile --features html --format html specs/001-diagnostics/tasks/004-formatting.typ /tmp/formatting.html` passes
