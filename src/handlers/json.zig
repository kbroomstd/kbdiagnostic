const std = @import("std");
const diag = @import("../diagnostic.zig");
const report = @import("../report.zig");

pub const JsonReportHandler = struct {
    base: report.ReportHandler = .{
        .ptr = null,
        .vtable = &vtable,
    },
    const vtable = report.ReportHandler.VTable{
        .debug = debug,
        .display = display,
        .trackCaller = trackCaller,
    };

    fn debug(_: *const anyopaque, err: *const diag.Diagnostic, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try display(null, err, writer);
    }
    fn display(_: *const anyopaque, err: *const diag.Diagnostic, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.writeAll("{\"message\":\"");
        try writer.writeAll(err.message());
        try writer.writeAll("\"");
        if (err.code()) |code| {
            try writer.writeAll(",\"code\":\"");
            try writer.writeAll(code);
            try writer.writeAll("\"");
        }
        if (err.help()) |help| {
            try writer.writeAll(",\"help\":\"");
            try writer.writeAll(help);
            try writer.writeAll("\"");
        }
        if (err.url()) |url| {
            try writer.writeAll(",\"url\":\"");
            try writer.writeAll(url);
            try writer.writeAll("\"");
        }
        if (err.related()) |related| {
            try writer.writeAll(",\"related\":[");
            for (related, 0..) |cause, i| {
                if (i != 0) try writer.writeAll(",");
                try writer.writeAll("{\"message\":\"");
                try writer.writeAll(cause.message());
                try writer.writeAll("\"}");
            }
            try writer.writeAll("]");
        }
        try writer.writeAll("}\n");
    }
    fn trackCaller(_: *anyopaque, _: *const std.builtin.SourceLocation) void {}
};

test "json output" {
    const D = struct {
        fn message(_: *const anyopaque) []const u8 { return "bad"; }
        fn code(_: *const anyopaque) ?[]const u8 { return "E1"; }
        const diag_vtable = diag.Diagnostic.VTable{
            .code = code, .severity = null, .help = null, .url = null, .sourceCode = null, .labels = null, .related = null, .diagnosticSource = null, .message = message,
        };
    };
    const d = diag.Diagnostic{ .ptr = undefined, .vtable = &D.diag_vtable };
    const handler = (JsonReportHandler{}).base;
    var buf: [128]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try handler.display(&d, &writer);
    try writer.flush();
    try std.testing.expect(std.mem.indexOf(u8, buf[0..writer.end], "\"message\":\"bad\"") != null);
}

test "json related" {
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
    const handler = (JsonReportHandler{}).base;
    var buf: [128]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try handler.display(&d, &writer);
    try writer.flush();
    try std.testing.expect(std.mem.indexOf(u8, buf[0..writer.end], "\"related\"") != null);
}
