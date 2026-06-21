const std = @import("std");
const diag = @import("../diagnostic.zig");
const report = @import("../report.zig");

pub const DebugReportHandler = struct {
    const Self = @This();
    pub fn base(self: *const Self) report.ReportHandler {
        return report.ReportHandler.implBy(self);
    }

    fn display(_: *const anyopaque, _: std.mem.Allocator, writer: *std.Io.Writer, err: *const diag.Diagnostic) std.Io.Writer.Error!void {
        try writer.print("Error: {s}\n", .{err.message()});
    }
};
