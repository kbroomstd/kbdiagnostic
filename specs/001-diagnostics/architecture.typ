= Architecture

== File Layout
Concrete implementation should live under `src/` with stable modules:

```text
src/
  lib.zig
  diagnostic.zig
  source.zig
  report.zig
  handlers/
    graphical.zig
    json.zig
    debug.zig
  theme/
    ansi.zig
    plain.zig
  span.zig
  severity.zig
  assert.zig
```

== Ownership
- `lib.zig` exports public API and re-exports types
- `diagnostic.zig` holds trait contract + helpers
- `span.zig` holds `SourceSpan`, `LabeledSpan`, `SpanContents`
- `source.zig` holds `SourceCode` contract + built-in source adapters
- `report.zig` holds `Report` wrapper + hook selection
- `handlers/graphical.zig` holds fancy human renderer
- `handlers/json.zig` holds structured renderer
- `handlers/debug.zig` holds plain fallback / debug handler
- `theme/` holds color and styling policy only
- `assert.zig` holds developer test helpers

== Public Surface
`lib.zig` should re-export:

- `Severity`
- `SourceSpan`
- `LabeledSpan`
- `SpanContents`
- `Diagnostic`
- `SourceCode`
- `ReportHandler`
- `Report`
- `GraphicalReportHandler`
- `JsonReportHandler`
- `DebugReportHandler`
- `supportsColor`
- `PlainTheme`
- `assert`

== Dependency Direction
- `span.zig` imports only `std`
- `severity.zig` imports only `std`
- `diagnostic.zig` imports `span.zig`, `severity.zig`, `source.zig`
- `source.zig` imports `span.zig`
- `report.zig` imports `diagnostic.zig`, `source.zig`, `handlers/*`
- `handlers/*` import `diagnostic.zig`, `span.zig`, `source.zig`, `theme/*`
- `theme/*` import only `std`
- `assert.zig` imports only `std` plus local public types

