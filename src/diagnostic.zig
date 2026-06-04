const std = @import("std");
const sev = @import("severity.zig");
const span = @import("span.zig");
const source = @import("source.zig");

pub const Diagnostic = struct {
    ptr: *const anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        code: ?*const fn (*const anyopaque) ?[]const u8,
        severity: ?*const fn (*const anyopaque) ?sev.Severity,
        help: ?*const fn (*const anyopaque) ?[]const u8,
        url: ?*const fn (*const anyopaque) ?[]const u8,
        sourceCode: ?*const fn (*const anyopaque) ?*const source.SourceCode,
        labels: ?*const fn (*const anyopaque) ?[]const span.LabeledSpan,
        related: ?*const fn (*const anyopaque) ?[]const Diagnostic,
        diagnosticSource: ?*const fn (*const anyopaque) ?*const Diagnostic,
        message: *const fn (*const anyopaque) []const u8,
    };

    pub fn message(self: *const Diagnostic) []const u8 { return self.vtable.message(self.ptr); }
    pub fn code(self: *const Diagnostic) ?[]const u8 {
        return if (self.vtable.code) |f| f(self.ptr) else null;
    }
    pub fn severity(self: *const Diagnostic) ?sev.Severity {
        return if (self.vtable.severity) |f| f(self.ptr) else null;
    }
    pub fn help(self: *const Diagnostic) ?[]const u8 {
        return if (self.vtable.help) |f| f(self.ptr) else null;
    }
    pub fn url(self: *const Diagnostic) ?[]const u8 {
        return if (self.vtable.url) |f| f(self.ptr) else null;
    }
    pub fn sourceCode(self: *const Diagnostic) ?*const source.SourceCode {
        return if (self.vtable.sourceCode) |f| f(self.ptr) else null;
    }
    pub fn labels(self: *const Diagnostic) ?[]const span.LabeledSpan {
        return if (self.vtable.labels) |f| f(self.ptr) else null;
    }

    pub fn related(self: *const Diagnostic) ?[]const Diagnostic {
        return if (self.vtable.related) |f| f(self.ptr) else null;
    }
    pub fn diagnosticSource(self: *const Diagnostic) ?*const Diagnostic {
        return if (self.vtable.diagnosticSource) |f| f(self.ptr) else null;
    }

    pub fn chain(self: *const Diagnostic) ?[]const Diagnostic {
        return self.related();
    }
};

test "default trait methods return none" {
    const d = Diagnostic{
        .ptr = undefined,
        .vtable = &.{ .code = null, .severity = null, .help = null, .url = null, .sourceCode = null, .labels = null, .related = null, .diagnosticSource = null, .message = struct {
            fn f(_: *const anyopaque) []const u8 {
                return "x";
            }
        }.f },
    };
    try std.testing.expect(d.code() == null);
    try std.testing.expect(d.help() == null);
}
