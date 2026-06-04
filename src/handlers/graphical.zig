const std = @import("std");
const diag = @import("../diagnostic.zig");
const span = @import("../span.zig");
const report = @import("../report.zig");

const dummy_ptr: *const anyopaque = @ptrFromInt(1);

pub const GraphicalReportHandler = struct {
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
        try display(dummy_ptr, err, writer);
    }
    fn display(_: *const anyopaque, err: *const diag.Diagnostic, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("Error: {s}\n", .{err.message()});
        if (err.code()) |code| try writer.print("code: {s}\n", .{code});
        if (err.help()) |help| try writer.print("help: {s}\n", .{help});
        if (err.url()) |url| try writer.print("url: {s}\n", .{url});
        if (err.sourceCode()) |src| {
            const sp: span.SourceSpan = if (err.labels()) |labels| blk: {
                if (labels.len > 0) break :blk labels[0].inner().*;
                break :blk .{ .offset = 0, .length = 0 };
            } else .{ .offset = 0, .length = 0 };
            const ctx = src.readSpan(&sp, 1, 1) catch unreachable;
            try writer.print("{s}:{d}:{d}\n", .{ ctx.name() orelse "<source>", ctx.line(), ctx.column() });
            try writer.writeAll(ctx.data());
            try writer.writeByte('\n');
        }
        if (err.labels()) |labels| {
            for (labels) |label| {
                try writer.print("label: {s} {any}\n", .{ label.label() orelse "", label.inner().* });
            }
        }
        if (err.related()) |related| {
            for (related) |cause| {
                try writer.print("caused by: {s}\n", .{cause.message()});
            }
        }
    }
    fn trackCaller(_: *anyopaque, _: *const std.builtin.SourceLocation) void {}
};

test "graphical output" {
    const D = struct {
        fn message(_: *const anyopaque) []const u8 { return "bad"; }
        fn code(_: *const anyopaque) ?[]const u8 { return "E1"; }
        fn help(_: *const anyopaque) ?[]const u8 { return "fix"; }
        fn url(_: *const anyopaque) ?[]const u8 { return "https://example.invalid"; }
        const diag_vtable = diag.Diagnostic.VTable{
            .code = code, .severity = null, .help = help, .url = url, .sourceCode = null, .labels = null, .related = null, .diagnosticSource = null, .message = message,
        };
    };
    const d = diag.Diagnostic{ .ptr = undefined, .vtable = &D.diag_vtable };
    const handler = (GraphicalReportHandler{}).base;
    var buf: [128]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try handler.display(&d, &writer);
    try writer.flush();
    try std.testing.expect(std.mem.indexOf(u8, buf[0..writer.end], "Error: bad") != null);
}

test "graphical related and missing labels" {
    const D = struct {
        fn message(_: *const anyopaque) []const u8 { return "root"; }
        fn related(_: *const anyopaque) []const diag.Diagnostic { return &.{ child }; }
        fn child_message(_: *const anyopaque) []const u8 { return "child"; }
        const child_vtable = diag.Diagnostic.VTable{
            .code = null, .severity = null, .help = null, .url = null, .sourceCode = null, .labels = null, .related = null, .diagnosticSource = null, .message = child_message,
        };
        const child = diag.Diagnostic{ .ptr = undefined, .vtable = &child_vtable };
        const diag_vtable = diag.Diagnostic.VTable{
            .code = null, .severity = null, .help = null, .url = null, .sourceCode = null, .labels = null, .related = related, .diagnosticSource = null, .message = message,
        };
    };
    const d = diag.Diagnostic{ .ptr = undefined, .vtable = &D.diag_vtable };
    const handler = (GraphicalReportHandler{}).base;
    var buf: [128]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try handler.display(&d, &writer);
    try writer.flush();
    try std.testing.expect(std.mem.indexOf(u8, buf[0..writer.end], "caused by: child") != null);
}
