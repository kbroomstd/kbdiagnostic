const lib = @import("lib.zig");

pub const Severity = lib.Severity;
pub const SourceSpan = lib.SourceSpan;
pub const LabeledSpan = lib.LabeledSpan;
pub const SpanContents = lib.SpanContents;
pub const Diagnostic = lib.Diagnostic;
pub const SourceCode = lib.SourceCode;
pub const ReportHandler = lib.ReportHandler;
pub const Report = lib.Report;
pub const GraphicalReportHandler = lib.GraphicalReportHandler;
pub const JsonReportHandler = lib.JsonReportHandler;
pub const DebugReportHandler = lib.DebugReportHandler;
pub const supportsColor = lib.supportsColor;
pub const PlainTheme = lib.PlainTheme;
pub const assert = lib.assert;
