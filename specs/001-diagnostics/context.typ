= Context

`kbdiagnostic` aims to provide beautiful failure reports for Zig apps. The project should follow `miette`'s split: diagnostic metadata, source lookup, render handler, report wrapper. Zig side should stay explicit: small structs, vtables only at edges, build-time generation if needed.
Primary render target is not generic formatting. It is close parity with `miette`'s `GraphicalReportHandler` and `JsonReportHandler`.

== Problem
Zig programs often expose errors as plain `!T` and `try` chains. That is good for control flow, but weak for human-facing failure output. Users need:

- clear top-level message
- location or span
- code context
- labels and notes
- optional help text
- chained causes
- renderer choice / handler selection

== Local Constraints
- Repo already uses Zig `0.16.x` refs under `.references`.
- Current code uses `std.Io`, `std.testing`, and `std.Build`.
- Need keep implementation compatible with project's existing build flow.

Naming rules from Zig langref:

- types use `TitleCase`
- functions and methods use `camelCase`
- variables, parameters, fields use `snake_case`
- namespaces / zero-field namespace structs use `snake_case`
- file names for types use `TitleCase`
- file names for namespaces use `snake_case`
- directory names use `snake_case`
- acronyms still follow normal casing rules, not all-caps

== Interface Guidance
From linked Ziggit discussion, interface pattern should stay explicit:

- `Diagnostic` contract surfaces code, severity, help, url, source, labels, related, source error
- `SourceCode` owns span reads, not renderer
- `ReportHandler` owns output style, not diagnostic data
- `Report` wraps boxed diagnostic for app-facing runtime use
- derive/codegen can reduce boilerplate for concrete types
- graphical and JSON handlers should match `miette` behavior as closely as practical, including field coverage and fallback rules

That maps well to diagnostics:

- `ReportHandler` can wrap output sinks
- `SourceCode` can wrap file or memory-backed snippets
- formatter can stay pure and testable

== Concepts
- `Diagnostic`: metadata trait contract
- `Report`: runtime wrapper around boxed diagnostic
- `LabeledSpan`: span plus optional label + primary flag
- `SourceCode`: snippet reader
- `ReportHandler`: renderer trait
- `Severity`: Advice / Warning / Error
