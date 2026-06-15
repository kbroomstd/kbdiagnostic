const std = @import("std");
const sev = @import("severity.zig");
const span = @import("span.zig");
const source = @import("source.zig");

pub const Diagnostic = @This();
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

pub fn implBy(impl_obj: anytype) Diagnostic {
    const delegate = DiagnosticDelegate(impl_obj);
    return .{
        .ptr = impl_obj,
        .vtable = &.{
            .code = delegate.code,
            .severity = delegate.severity,
            .help = delegate.help,
            .url = delegate.url,
            .sourceCode = delegate.sourceCode,
            .labels = delegate.labels,
            .related = delegate.related,
            .diagnosticSource = delegate.diagnosticSource,
            .message = delegate.message,
        },
    };
}

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

inline fn DiagnosticDelegate(impl_obj: anytype) type {
    const ImplType = @TypeOf(impl_obj);
    return struct {
        fn code(impl: *const anyopaque) ?[]const u8 {
            const obj = TPtr(ImplType, impl);
            if (@hasDecl(ImplType, "code")) return obj.code();
            return @field(obj, "code");
        }
        fn severity(impl: *const anyopaque) ?sev.Severity {
            const obj = TPtr(ImplType, impl);
            if (@hasDecl(ImplType, "severity")) return obj.severity();
            return @field(obj, "severity");
        }
        fn help(impl: *const anyopaque) ?[]const u8 {
            const obj = TPtr(ImplType, impl);
            if (@hasDecl(ImplType, "help")) return obj.help();
            return @field(obj, "help");
        }
        fn url(impl: *const anyopaque) ?[]const u8 {
            const obj = TPtr(ImplType, impl);
            if (@hasDecl(ImplType, "url")) return obj.url();
            return @field(obj, "url");
        }
        fn sourceCode(impl: *const anyopaque) ?*const source.SourceCode {
            const obj = TPtr(ImplType, impl);
            if (@hasDecl(ImplType, "sourceCode")) return obj.sourceCode();
            return @field(obj, "source");
        }
        fn labels(impl: *const anyopaque) ?[]const span.LabeledSpan {
            const obj = TPtr(ImplType, impl);
            if (@hasDecl(ImplType, "labels")) return obj.labels();
            const value = @field(obj, "labels");
            return if (value.len == 0) null else value;
        }
        fn related(impl: *const anyopaque) ?[]const Diagnostic {
            const obj = TPtr(ImplType, impl);
            if (@hasDecl(ImplType, "related")) return obj.related();
            const value = @field(obj, "related");
            return if (value.len == 0) null else value;
        }
        fn diagnosticSource(impl: *const anyopaque) ?*const Diagnostic {
            const obj = TPtr(ImplType, impl);
            if (@hasDecl(ImplType, "diagnosticSource")) return obj.diagnosticSource();
            return null;
        }
        fn message(impl: *const anyopaque) []const u8 {
            const obj = TPtr(ImplType, impl);
            if (@hasDecl(ImplType, "message")) return obj.message();
            return @field(obj, "message");
        }
    };
}

fn TPtr(T: type, opaque_ptr: *const anyopaque) T {
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
