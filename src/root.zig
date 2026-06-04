pub const severity = @import("severity.zig");
pub const span = @import("span.zig");
pub const source = @import("source.zig");
pub const diagnostic = @import("diagnostic.zig");
pub const report = @import("report.zig");
pub const handlers = struct {
    pub const json = @import("handlers/json.zig");
    pub const debug = @import("handlers/debug.zig");
};
pub const theme = struct {
    pub const ansi = @import("theme/ansi.zig");
    pub const plain = @import("theme/plain.zig");
};
pub const assert = @import("assert.zig");

pub const Severity = severity.Severity;
pub const SourceSpan = span.SourceSpan;
pub const LabeledSpan = span.LabeledSpan;
pub const SpanContents = span.SpanContents;
pub const Diagnostic = diagnostic.Diagnostic;
pub const DiagnosticData = diagnostic.DiagnosticData;
pub const SourceCode = source.SourceCode;
pub const NamedSource = source.NamedSource;
pub const ReportHandler = report.ReportHandler;
pub const Report = report.Report;
pub const GraphicalReportHandler = @import("handlers/GraphicalReportHandler.zig");
pub const JsonReportHandler = handlers.json.JsonReportHandler;
pub const DebugReportHandler = handlers.debug.DebugReportHandler;
pub const supportsColor = theme.ansi.supportsColor;
pub const PlainTheme = theme.plain.PlainTheme;
