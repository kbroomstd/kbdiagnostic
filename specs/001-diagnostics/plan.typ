= Purpose
Build `kbdiagnostic` into a Zig diagnostics crate with polished error reports, notes, spans, labels, and source context. Target feel: `miette`-style output, but shaped by Zig idioms and this repo's current `std.Io` / build setup.

== Why Now
Current repo is only scaffold. No diagnostics model, no renderer, no public API. This spec defines core shape before code grows.

== Design Thesis
Model core API like `miette`: `Diagnostic` trait-like contract, separate `ReportHandler`, separate `SourceCode`, plus `Report` wrapper for runtime use. Keep implementation explicit and Zig-native: vtables where needed, build-time codegen if boilerplate grows.
Render side should specifically aim for strong parity with `miette`'s `GraphicalReportHandler` and `JsonReportHandler`, including formatting shape, metadata coverage, and output stability.
`009-graphical-parity` owns the explicit port strategy for `GraphicalReportHandler`, including all options except syntax highlighting, with the current Zig implementation allowed to be replaced outright if that is the clearest port.

== Non-Goals
- Full `miette` feature parity.
- Macro-heavy API.
- Language-level interfaces.
- ANSI styling engine beyond first-pass palette.

== Acceptance
- Can define diagnostic metadata + source + labels + related errors.
- Can render same diagnostic to stderr or string buffer through handler.
- Can attach source span and show context lines through source abstraction.
- Can provide `GraphicalReportHandler`-class output and `JsonReportHandler` output close to `miette`.
- Interface shape stays idiomatic for Zig 0.16-era code.
