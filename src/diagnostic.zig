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

    pub fn message(self: *const Diagnostic) []const u8 {
        return self.vtable.message(self.ptr);
    }
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

pub const DiagnosticData = struct {
    message: []const u8,
    code: ?[]const u8 = null,
    severity: ?sev.Severity = null,
    help: ?[]const u8 = null,
    url: ?[]const u8 = null,
    source: ?*const source.SourceCode = null,
    labels: []const span.LabeledSpan = &.{},
    related: []const Diagnostic = &.{},

    pub fn diagnostic(self: *const @This()) Diagnostic {
        return .{ .ptr = self, .vtable = &vtable };
    }

    fn codeFn(ptr: *const anyopaque) ?[]const u8 {
        const self: *const @This() = @ptrCast(@alignCast(ptr));
        return self.code;
    }
    fn severityFn(ptr: *const anyopaque) ?sev.Severity {
        const self: *const @This() = @ptrCast(@alignCast(ptr));
        return self.severity;
    }
    fn helpFn(ptr: *const anyopaque) ?[]const u8 {
        const self: *const @This() = @ptrCast(@alignCast(ptr));
        return self.help;
    }
    fn urlFn(ptr: *const anyopaque) ?[]const u8 {
        const self: *const @This() = @ptrCast(@alignCast(ptr));
        return self.url;
    }
    fn sourceFn(ptr: *const anyopaque) ?*const source.SourceCode {
        const self: *const @This() = @ptrCast(@alignCast(ptr));
        return self.source;
    }
    fn labelsFn(ptr: *const anyopaque) ?[]const span.LabeledSpan {
        const self: *const @This() = @ptrCast(@alignCast(ptr));
        return if (self.labels.len == 0) null else self.labels;
    }
    fn relatedFn(ptr: *const anyopaque) ?[]const Diagnostic {
        const self: *const @This() = @ptrCast(@alignCast(ptr));
        return if (self.related.len == 0) null else self.related;
    }
    fn diagnosticSourceFn(_: *const anyopaque) ?*const Diagnostic {
        return null;
    }
    fn messageFn(ptr: *const anyopaque) []const u8 {
        const self: *const @This() = @ptrCast(@alignCast(ptr));
        return self.message;
    }

    const vtable = Diagnostic.VTable{
        .code = codeFn,
        .severity = severityFn,
        .help = helpFn,
        .url = urlFn,
        .sourceCode = sourceFn,
        .labels = labelsFn,
        .related = relatedFn,
        .diagnosticSource = diagnosticSourceFn,
        .message = messageFn,
    };
};

inline fn DiagnosticDelegate(impl_obj: anytype) type {
    const ImplType = @TypeOf(impl_obj);
    return struct {
        fn log(impl: *anyopaque, msg: []const u8) void {
            TPtr(ImplType, impl).log(msg);
        }

        fn setLevel(impl: *anyopaque, level: usize) void {
            TPtr(ImplType, impl).setLevel(level);
        }
    };
}

fn TPtr(T: type, opaque_ptr: *anyopaque) T {
    return @as(T, @ptrCast(@alignCast(opaque_ptr)));
}

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
