= Design

== Core Shape
`Diagnostic` should be a trait-like contract, not a flat data struct. Concrete error types expose metadata by implementing methods.

Relevant methods:

- `code`
- `severity`
- `help`
- `url`
- `source_code`
- `labels`
- `related`
- `diagnostic_source`

Concrete value types are still useful for helper data:

- `Severity`
- `LabeledSpan`
- `SourceSpan`
- `Report`

Required concrete API surface:

- `pub const Severity = enum { Advice, Warning, Error };`
- `pub const SourceSpan = struct { offset: usize, length: usize };`
- `pub const LabeledSpan = struct { label: ?[]const u8, span: SourceSpan, primary: bool };`
- `pub const Diagnostic = trait-like contract`
- `pub const Report = struct { inner: *const dyn Diagnostic, handler: *const dyn ReportHandler };`
- `pub const GraphicalReportHandler = struct { ... };`
- `pub const JsonReportHandler = struct { ... };`
- `pub const SourceCode = trait-like contract`
- `pub const SpanContents = struct { data: []const u8, span: SourceSpan, name: ?[]const u8, line: usize, column: usize, line_count: usize, language: ?[]const u8 };`

File ownership:

- `severity.zig` owns `Severity` only
- `span.zig` owns `SourceSpan`, `LabeledSpan`, `SpanContents`
- `diagnostic.zig` owns `Diagnostic` contract and helper type aliases for labels/notes/related values
- `source.zig` owns `SourceCode` contract and built-in adapters for `[]const u8`, `[]u8`, file-backed source, and named source
- `report.zig` owns `Report`, `ReportHandler`, `setHook`, `getDefaultHandler`, and dynamic wrapper glue
- `handlers/graphical.zig` owns human formatter and its internal state machine
- `handlers/json.zig` owns JSON serializer and JSON schema shape
- `handlers/debug.zig` owns plain fallback / debug formatter
- `theme/ansi.zig` owns color detection and escape selection
- `theme/plain.zig` owns no-color style policy
- `assert.zig` owns developer helpers for tests and examples

== Rendering Model
Rendering splits into two layers:

1. normalize diagnostic into a render plan
2. render plan into target sink

This keeps formatting rules isolated from I/O.

Two first-class renderers matter most:

- `GraphicalReportHandler`: human-facing ANSI/Unicode report, close to `miette`
- `JsonReportHandler`: machine-facing structured output, close to `miette`

== Interface Model
Use Zig-style interface structs, not language features, for the Zig implementation of handler/source plumbing.

Handler shape:

- public wrapper type owns `impl` pointer + vtable pointer
- `fromNamedMethods` or equivalent builds wrapper from concrete type
- wrapper methods forward to vtable

Source shape:

- source reader exposes `getLine`, `getSpan`, `getName`
- can be backed by file text, embedded text, or caller-provided buffers

== Dynamic Dispatch Boundary
Only these parts need runtime polymorphism:

- output sink
- source resolver

Everything else should remain concrete and comptime-friendly.

== Formatting Rules
Output should prefer:

- code first, then snippet, then labels, then notes/help
- support fancy ANSI/Unicode mode and plain fallback
- support code links where possible

`GraphicalReportHandler` should preserve the same broad behavior as `miette`:

- severity-aware headline
- labels and source snippets
- cause chain
- help / code / url output
- plain fallback when color or Unicode unavailable

`JsonReportHandler` should emit structured diagnostic data with stable keys and enough detail to reconstruct human output later.

If terminal lacks color, plain text must still be readable.

== API Contracts
`LabeledSpan` constructors:

- `new(label: ?[]const u8, offset: usize, len: usize) LabeledSpan`
- `newWithSpan(label: ?[]const u8, span: SourceSpan) LabeledSpan`
- `newPrimaryWithSpan(label: ?[]const u8, span: SourceSpan) LabeledSpan`
- `at(span: SourceSpan, label: []const u8) LabeledSpan`
- `atOffset(offset: usize, label: []const u8) LabeledSpan`
- `underline(span: SourceSpan) LabeledSpan`

`LabeledSpan` accessors:

- `label() ?[]const u8`
- `inner() *const SourceSpan`
- `offset() usize`
- `len() usize`
- `isEmpty() bool`
- `primary() bool`

`SourceCode` contract:

- `readSpan(self, span: *const SourceSpan, context_lines_before: usize, context_lines_after: usize) !SpanContents`

`Report` contract:

- `new(error: any Diagnostic, handler: any ReportHandler) Report`
- `handler(self: *const Report) *const ReportHandler`
- `diagnostic(self: *const Report) *const Diagnostic`
- `debug(self: *const Report, writer: *std.Io.Writer) std.Io.Writer.Error!void`
- `display(self: *const Report, writer: *std.Io.Writer) std.Io.Writer.Error!void`

`ReportHandler` contract:

- `debug(self: *const ReportHandler, error: *const Diagnostic, writer: *std.Io.Writer) std.Io.Writer.Error!void`
- `display(self: *const ReportHandler, error: *const Diagnostic, writer: *std.Io.Writer) std.Io.Writer.Error!void`
- `trackCaller(self: *ReportHandler, location: *const std.builtin.SourceLocation) void`

`SpanContents` accessors:

- `data() []const u8`
- `span() *const SourceSpan`
- `name() ?[]const u8`
- `line() usize`
- `column() usize`
- `lineCount() usize`
- `language() ?[]const u8`


== Extension Hooks
Future additions should fit without breaking core shape:

- JSON or machine-readable handler
- theme selection
- multi-span diagnostics
- backtrace integration
