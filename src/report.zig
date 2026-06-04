const std = @import("std");
const diag = @import("diagnostic.zig");
const graphical = @import("handlers/graphical.zig");
const json = @import("handlers/json.zig");
const debug = @import("handlers/debug.zig");

pub const ReportHandler = struct {
    ptr: *const anyopaque,
    vtable: *const VTable,
    pub const VTable = struct {
        debug: *const fn (*const anyopaque, *const diag.Diagnostic, *std.Io.Writer) std.Io.Writer.Error!void,
        display: *const fn (*const anyopaque, *const diag.Diagnostic, *std.Io.Writer) std.Io.Writer.Error!void,
        trackCaller: *const fn (*anyopaque, *const std.builtin.SourceLocation) void,
    };

    pub fn debug(self: *const ReportHandler, err: *const diag.Diagnostic, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try self.vtable.debug(self.ptr, err, writer);
    }
    pub fn display(self: *const ReportHandler, err: *const diag.Diagnostic, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try self.vtable.display(self.ptr, err, writer);
    }
    pub fn trackCaller(self: *ReportHandler, location: *const std.builtin.SourceLocation) void {
        self.vtable.trackCaller(@constCast(self.ptr), location);
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

    pub fn display(self: *const Report, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try self.report_handler.display(self.inner, writer);
    }
    pub fn debug(self: *const Report, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try self.report_handler.debug(self.inner, writer);
    }
};

var default_handler: ReportHandler = .{
    .ptr = @ptrFromInt(1),
    .vtable = &.{ .debug = debugFallback, .display = displayFallback, .trackCaller = trackCallerFallback },
};

pub fn getDefaultHandler() ReportHandler {
    return default_handler;
}

pub fn setHook(handler: *const ReportHandler) void {
    default_handler = handler.*;
}

fn debugFallback(_: *const anyopaque, err: *const diag.Diagnostic, writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try writer.print("debug: {s}\n", .{err.message()});
}
fn displayFallback(_: *const anyopaque, err: *const diag.Diagnostic, writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try writer.print("Error: {s}\n", .{err.message()});
}
fn trackCallerFallback(_: *anyopaque, _: *const std.builtin.SourceLocation) void {}

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
    try handler.display(&d, &writer);
    try writer.flush();
    try std.testing.expect(std.mem.indexOf(u8, buf[0..writer.end], "Error: msg") != null);
}

test "hook swap" {
    const h = getDefaultHandler();
    setHook(&h);
    try std.testing.expect(@intFromPtr(getDefaultHandler().ptr) == @intFromPtr(h.ptr));
}
