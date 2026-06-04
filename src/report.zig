const std = @import("std");
const diag = @import("diagnostic.zig");

pub const ReportHandler = struct {
    ptr: *const anyopaque,
    vtable: *const VTable,
    pub const VTable = struct {
        display: *const fn (*const anyopaque, std.mem.Allocator, *std.Io.Writer, *const diag.Diagnostic) std.Io.Writer.Error!void,
    };

    pub fn display(self: *const ReportHandler, allocator: std.mem.Allocator, writer: *std.Io.Writer, err: *const diag.Diagnostic) std.Io.Writer.Error!void {
        try self.vtable.display(self.ptr, allocator, writer, err);
    }
};

pub const Report = struct {
    inner: *const diag.Diagnostic,
    report_handler: *const ReportHandler,

    pub fn new(inner: *const diag.Diagnostic, rh: *const ReportHandler) Report {
        return .{ .inner = inner, .report_handler = rh };
    }

    pub fn diagnostic(self: *const Report) *const diag.Diagnostic {
        return self.inner;
    }
    pub fn handler(self: *const Report) *const ReportHandler {
        return self.report_handler;
    }

    pub fn display(self: *const Report, allocator: std.mem.Allocator, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try self.report_handler.display(allocator, writer, self.inner);
    }
};

var default_handler: ReportHandler = .{
    .ptr = @ptrFromInt(1),
    .vtable = &.{ .display = displayFallback },
};

pub fn getDefaultHandler() ReportHandler {
    return default_handler;
}

pub fn setHook(handler: *const ReportHandler) void {
    default_handler = handler.*;
}

fn displayFallback(_: *const anyopaque, _: std.mem.Allocator, writer: *std.Io.Writer, err: *const diag.Diagnostic) std.Io.Writer.Error!void {
    try writer.print("Error: {s}\n", .{err.message()});
}

test "dispatch through wrapper" {
    const D = struct {
        fn message(_: *const anyopaque) []const u8 {
            return "msg";
        }
        const diag_vtable = diag.Diagnostic.VTable{
            .code = null,
            .severity = null,
            .help = null,
            .url = null,
            .sourceCode = null,
            .labels = null,
            .related = null,
            .diagnosticSource = null,
            .message = message,
        };
    };
    const d = diag.Diagnostic{ .ptr = undefined, .vtable = &D.diag_vtable };
    const handler = getDefaultHandler();
    var buf: [64]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try handler.display(std.testing.allocator, &writer, &d);
    try writer.flush();
    try std.testing.expect(std.mem.indexOf(u8, buf[0..writer.end], "Error: msg") != null);
}

test "hook swap" {
    const h = getDefaultHandler();
    setHook(&h);
    try std.testing.expect(@intFromPtr(getDefaultHandler().ptr) == @intFromPtr(h.ptr));
}
