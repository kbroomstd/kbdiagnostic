const sev = @import("severity.zig");
const span = @import("span.zig");
const src = @import("source.zig");
const diagnostic = @import("diagnostic.zig");

pub const DiagnosticData = @This();
message: []const u8,
code: ?[]const u8 = null,
severity: ?sev.Severity = null,
help: ?[]const u8 = null,
url: ?[]const u8 = null,
source: ?*const src.SourceCode = null,
labels: []const span.LabeledSpan = &.{},
related: []const diagnostic.Diagnostic = &.{},
