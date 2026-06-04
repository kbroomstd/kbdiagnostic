= Graphical Parity

== Goal
Port `miette`-class graphical reporting into `src/handlers/graphical.zig` with feature parity for all exposed options except syntax highlighting.

== Scope
- output shape
- widths and wrapping
- nested causes and related blocks
- headers, footers, labels, urls, help
- color fallback and severity styling
- option surface except syntax highlighting

== Strategy
- treat current Zig impl as disposable draft
- port behavior, do not reimagine it
- follow inverse of `PORTING.md`: keep structure close to source semantics, then adapt Zig-specific pieces only where needed
- prefer direct line-by-line parity with `miette` before any cleanup pass

== Baseline Inputs
- `PORTING.md`
- `specs/001-diagnostics/plan.typ`
- `specs/001-diagnostics/tasks/002-renderer-interface.typ`
- `specs/001-diagnostics/tasks/004-formatting.typ`

== Requirements
- `GraphicalReportHandler` matches `miette` output for all non-syntax-highlighting options
- wrap logic matches `miette` width behavior
- nested related / cause recursion matches `miette`
- plain-text fallback matches `miette`
- current Zig implementation may be replaced from scratch if that gets closer to parity

== Tests
- showcase diff command between Zig and Rust outputs
- targeted golden cases for nested related blocks
- targeted golden cases for wrapped header / footer / help output
- targeted golden cases for ANSI on/off parity

== Done
- `src/handlers/graphical.zig` implements full non-syntax-highlighting parity surface
- showcase diff command is clean or limited to documented non-goals
- task compiles with Typst HTML export
- `typst compile --features html --format html specs/001-diagnostics/tasks/009-graphical-parity.typ /tmp/graphical-parity.html` passes
