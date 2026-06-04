const std = @import("std");
const diag = @import("../diagnostic.zig");
const report = @import("../report.zig");

const dummy_ptr: *const anyopaque = @ptrFromInt(1);

pub const DebugReportHandler = struct {
    base: report.ReportHandler = .{
        .ptr = dummy_ptr,
        .vtable = &vtable,
    },
    const vtable = report.ReportHandler.VTable{
        .debug = debug,
        .display = display,
        .trackCaller = trackCaller,
    };

    fn debug(_: *const anyopaque, err: *const diag.Diagnostic, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("debug: {s}\n", .{err.message()});
    }
    fn display(_: *const anyopaque, _: std.mem.Allocator, err: *const diag.Diagnostic, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("Error: {s}\n", .{err.message()});
    }
    fn trackCaller(_: *anyopaque, _: *const std.builtin.SourceLocation) void {}
};
