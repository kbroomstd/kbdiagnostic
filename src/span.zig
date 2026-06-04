const std = @import("std");

pub const SourceSpan = struct {
    offset: usize,
    length: usize,

    pub fn jsonStringify(self: SourceSpan, jw: anytype) !void {
        try jw.beginObject();
        try jw.objectField("offset");
        try jw.print("{}", .{self.offset});
        try jw.objectField("length");
        try jw.print("{}", .{self.length});
        try jw.endObject();
    }

    pub fn format(self: SourceSpan, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("{d}:{d}", .{ self.offset, self.length });
    }
};

pub const LabeledSpan = struct {
    _label: ?[]const u8,
    _span: SourceSpan,
    _primary: bool,

    pub fn new(lbl: ?[]const u8, off: usize, length: usize) LabeledSpan {
        return .{ ._label = lbl, ._span = .{ .offset = off, .length = length }, ._primary = false };
    }

    pub fn newPrimary(lbl: ?[]const u8, off: usize, length: usize) LabeledSpan {
        return .{ ._label = lbl, ._span = .{ .offset = off, .length = length }, ._primary = true };
    }
    pub fn newWithSpan(lbl: ?[]const u8, sp: SourceSpan) LabeledSpan {
        return .{ ._label = lbl, ._span = sp, ._primary = false };
    }
    pub fn newPrimaryWithSpan(lbl: ?[]const u8, sp: SourceSpan) LabeledSpan {
        return .{ ._label = lbl, ._span = sp, ._primary = true };
    }
    pub fn at(sp: SourceSpan, lbl: []const u8) LabeledSpan {
        return .{ ._label = lbl, ._span = sp, ._primary = false };
    }
    pub fn atOffset(off: usize, lbl: []const u8) LabeledSpan {
        return .{ ._label = lbl, ._span = .{ .offset = off, .length = 1 }, ._primary = false };
    }
    pub fn underline(span: SourceSpan) LabeledSpan {
        return .{ ._label = null, ._span = span, ._primary = true };
    }
    pub fn label(self: *const LabeledSpan) ?[]const u8 { return self._label; }
    pub fn inner(self: *const LabeledSpan) *const SourceSpan { return &self._span; }
    pub fn offset(self: *const LabeledSpan) usize { return self._span.offset; }
    pub fn len(self: *const LabeledSpan) usize { return self._span.length; }
    pub fn isEmpty(self: *const LabeledSpan) bool { return self._span.length == 0; }
    pub fn primary(self: *const LabeledSpan) bool { return self._primary; }

    pub fn jsonStringify(self: LabeledSpan, jw: anytype) !void {
        try jw.beginObject();
        if (self._label) |lbl| {
            try jw.objectField("label");
            try jw.write(lbl);
        }
        try jw.objectField("span");
        try jw.write(self._span);
        try jw.objectField("primary");
        try jw.write(self._primary);
        try jw.endObject();
    }

    pub fn format(self: LabeledSpan, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        if (self._label) |lbl| try writer.print("{s}@{any}", .{ lbl, self._span }) else try writer.print("@{any}", .{self._span});
        if (self._primary) try writer.writeAll(" primary");
    }
};

pub const SpanContents = struct {
    _data: []const u8,
    _span: SourceSpan,
    _name: ?[]const u8 = null,
    _line: usize = 1,
    _column: usize = 1,
    _line_count: usize = 1,
    _language: ?[]const u8 = null,

    pub fn data(self: *const SpanContents) []const u8 { return self._data; }
    pub fn span(self: *const SpanContents) *const SourceSpan { return &self._span; }
    pub fn name(self: *const SpanContents) ?[]const u8 { return self._name; }
    pub fn line(self: *const SpanContents) usize { return self._line; }
    pub fn column(self: *const SpanContents) usize { return self._column; }
    pub fn lineCount(self: *const SpanContents) usize { return self._line_count; }
    pub fn language(self: *const SpanContents) ?[]const u8 { return self._language; }
};

test "labeled span variants" {
    const a = LabeledSpan.new(null, 1, 2);
    try std.testing.expect(!a.primary());
    const b = LabeledSpan.newPrimaryWithSpan("x", .{ .offset = 3, .length = 4 });
    try std.testing.expect(b.primary());
    try std.testing.expectEqual(@as(usize, 3), b.offset());
}

test "span hooks" {
    var buf: [64]u8 = undefined;
    const text = try std.fmt.bufPrint(&buf, "{any}", .{SourceSpan{ .offset = 1, .length = 2 }});
    try std.testing.expect(std.mem.indexOf(u8, text, "1:2") != null);
    const json = try std.json.Stringify.valueAlloc(std.testing.allocator, SourceSpan{ .offset = 3, .length = 4 }, .{});
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"offset\":3") != null);

    const label_json = try std.json.Stringify.valueAlloc(std.testing.allocator, LabeledSpan.new("lab", 1, 2), .{});
    defer std.testing.allocator.free(label_json);
    try std.testing.expect(std.mem.indexOf(u8, label_json, "\"label\":\"lab\"") != null);
}

test "span eql" {
    try std.testing.expect(std.meta.eql(SourceSpan{ .offset = 1, .length = 2 }, SourceSpan{ .offset = 1, .length = 2 }));
    try std.testing.expect(!std.meta.eql(SourceSpan{ .offset = 1, .length = 2 }, SourceSpan{ .offset = 2, .length = 2 }));
    try std.testing.expect(std.meta.eql(LabeledSpan.new("x", 1, 2), LabeledSpan.new("x", 1, 2)));
}
