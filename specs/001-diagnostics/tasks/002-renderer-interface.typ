= Renderer Interface

== Goal
Define explicit `ReportHandler`-style interface for writing diagnostics to `std.Io.Writer`, with `GraphicalReportHandler` and `JsonReportHandler` as primary implementations.

== Scope
- interface wrapper type
- vtable wiring
- graphical handler
- JSON handler
- test double handler

== Baseline Inputs
- Ziggit interface pattern
- `std.Io.Writer` usage in `src/main.zig`

== Requirements
- interface wrapper owns impl pointer + dispatch table
- wrapper methods expose `debug`, `display`, and caller tracking
- can wrap concrete handler without heap allocation if possible
- output should closely match `miette`'s `GraphicalReportHandler` and `JsonReportHandler`

== Tests
- render to buffer
- render through mock sink
- verify dispatch through wrapper
- compare graphical output against fixture
- compare JSON output against fixture
- plain fallback fixture with color disabled
- handler handles missing labels without panic

== Done
- `src/report.zig` and `src/handlers/{graphical,json,debug}.zig` exist
- `ReportHandler`, `GraphicalReportHandler`, `JsonReportHandler`, `DebugReportHandler` exported from `src/lib.zig`
- fixture tests cover all items in `== Tests`
- `typst compile --features html --format html specs/001-diagnostics/tasks/002-renderer-interface.typ /tmp/renderer-interface.html` passes
