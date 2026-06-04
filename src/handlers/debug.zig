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
        .display = display,
    };

    fn display(_: *const anyopaque, _: std.mem.Allocator, writer: *std.Io.Writer, err: *const diag.Diagnostic) std.Io.Writer.Error!void {
        try writer.print("Error: {s}\n", .{err.message()});
    }
};
