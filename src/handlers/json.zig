const std = @import("std");
const diag = @import("../diagnostic.zig");
const report = @import("../report.zig");
const sev = @import("../severity.zig");
const source = @import("../source.zig");

const dummy_ptr: *const anyopaque = @ptrFromInt(1);

pub const JsonReportHandler = struct {
    base: report.ReportHandler = .{ .ptr = dummy_ptr, .vtable = &vtable },

    const vtable = report.ReportHandler.VTable{
        .debug = debug,
        .display = display,
        .trackCaller = trackCaller,
    };

    fn debug(_: *const anyopaque, err: *const diag.Diagnostic, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try display(dummy_ptr, err, writer);
    }

    fn escape(writer: *std.Io.Writer, s: []const u8) std.Io.Writer.Error!void {
        for (s) |c| switch (c) {
            '\\' => try writer.writeAll("\\\\"),
            '"' => try writer.writeAll("\\\""),
            '\r' => try writer.writeAll("\\r"),
            '\n' => try writer.writeAll("\\n"),
            '\t' => try writer.writeAll("\\t"),
            0x08 => try writer.writeAll("\\b"),
            0x0c => try writer.writeAll("\\f"),
            else => try writer.writeByte(c),
        };
    }

    fn severityName(s: ?sev.Severity) []const u8 {
        return switch (s orelse .Error) {
            .Error => "error",
            .Warning => "warning",
            .Advice => "advice",
        };
    }

    fn display(_: *const anyopaque, err: *const diag.Diagnostic, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try renderReport(writer, err, null);
        try writer.writeByte('\n');
    }

    fn renderReport(writer: *std.Io.Writer, err: *const diag.Diagnostic, parent_src: ?*const source.SourceCode) std.Io.Writer.Error!void {
        try writer.writeAll("{\"message\": \"");
        try escape(writer, err.message());
        try writer.writeAll("\"");
        if (err.code()) |code| {
            try writer.writeAll(",\"code\": \"");
            try escape(writer, code);
            try writer.writeAll("\"");
        }
        try writer.writeAll(",\"severity\": \"");
        try writer.writeAll(severityName(err.severity()));
        try writer.writeAll("\"");
        try renderCauses(writer, err);
        if (err.url()) |url| {
            try writer.writeAll(",\"url\": \"");
            try escape(writer, url);
            try writer.writeAll("\"");
        }
        if (err.help()) |help| {
            try writer.writeAll(",\"help\": \"");
            try escape(writer, help);
            try writer.writeAll("\"");
        }
        const src = err.sourceCode() orelse parent_src;
        if (src) |s| {
            try renderFilename(writer, err, s);
        }
        try writer.writeAll(",\"labels\": [");
        if (err.labels()) |labels| {
            for (labels, 0..) |label, i| {
                if (i != 0) try writer.writeAll(",");
                try writer.writeAll("{");
                if (label.label()) |lbl| {
                    try writer.writeAll("\"label\": \"");
                    try escape(writer, lbl);
                    try writer.writeAll("\",");
                }
                try writer.writeAll("\"span\": {\"offset\": ");
                try writer.print("{}", .{label.offset()});
                try writer.writeAll(",\"length\": ");
                try writer.print("{}", .{label.len()});
                try writer.writeAll("}}");
            }
        }
        try writer.writeAll("],\"related\": [");
        if (err.related()) |related| {
            for (related, 0..) |rel, i| {
                if (i != 0) try writer.writeAll(",");
                try renderReport(writer, &rel, src);
            }
        }
        try writer.writeAll("]}");
    }

    fn renderCauses(writer: *std.Io.Writer, err: *const diag.Diagnostic) std.Io.Writer.Error!void {
        try writer.writeAll(",\"causes\": [");
        var current = err.diagnosticSource();
        var first = true;
        while (current) |cause| {
            if (!first) try writer.writeAll(",");
            first = false;
            try writer.writeAll("\"");
            try escape(writer, cause.message());
            try writer.writeAll("\"");
            current = cause.diagnosticSource();
        }
        try writer.writeAll("]");
    }

    fn renderFilename(writer: *std.Io.Writer, err: *const diag.Diagnostic, src: *const source.SourceCode) std.Io.Writer.Error!void {
        try writer.writeAll(",\"filename\": \"");
        if (err.labels()) |labels| {
            if (labels.len > 0) {
                const sp = labels[0].inner().*;
                const ctx = src.readSpan(&sp, 0, 0) catch {
                    try writer.writeAll("\"");
                    return;
                };
                try escape(writer, ctx.name() orelse "");
            }
        }
        try writer.writeAll("\"");
    }

    fn trackCaller(_: *anyopaque, _: *const std.builtin.SourceLocation) void {}
};

test "json output" {
    const D = struct {
        fn message(_: *const anyopaque) []const u8 {
            return "bad";
        }
        fn code(_: *const anyopaque) ?[]const u8 {
            return "E1";
        }
        const diag_vtable = diag.Diagnostic.VTable{
            .code = code,
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
    const handler = (JsonReportHandler{}).base;
    var buf: [128]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try handler.display(&d, &writer);
    try writer.flush();
    try std.testing.expect(std.mem.indexOf(u8, buf[0..writer.end], "\"message\": \"bad\"") != null);
}
