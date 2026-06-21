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
    label_: ?[]const u8,
    span_: SourceSpan,
    primary_: bool,

    pub fn new(lbl: ?[]const u8, off: usize, length: usize) LabeledSpan {
        return .{ .label_ = lbl, .span_ = .{ .offset = off, .length = length }, .primary_ = false };
    }

    pub fn newPrimary(lbl: ?[]const u8, off: usize, length: usize) LabeledSpan {
        return .{ .label_ = lbl, .span_ = .{ .offset = off, .length = length }, .primary_ = true };
    }
    pub fn newWithSpan(lbl: ?[]const u8, sp: SourceSpan) LabeledSpan {
        return .{ .label_ = lbl, .span_ = sp, .primary_ = false };
    }
    pub fn newPrimaryWithSpan(lbl: ?[]const u8, sp: SourceSpan) LabeledSpan {
        return .{ .label_ = lbl, .span_ = sp, .primary_ = true };
    }
    pub fn at(sp: SourceSpan, lbl: []const u8) LabeledSpan {
        return .{ .label_ = lbl, .span_ = sp, .primary_ = false };
    }
    pub fn atOffset(off: usize, lbl: []const u8) LabeledSpan {
        return .{ .label_ = lbl, .span_ = .{ .offset = off, .length = 1 }, .primary_ = false };
    }
    pub fn underline(span: SourceSpan) LabeledSpan {
        return .{ .label_ = null, .span_ = span, .primary_ = true };
    }
    pub fn label(self: *const LabeledSpan) ?[]const u8 {
        return self.label_;
    }
    pub fn inner(self: *const LabeledSpan) *const SourceSpan {
        return &self.span_;
    }
    pub fn offset(self: *const LabeledSpan) usize {
        return self.span_.offset;
    }
    pub fn len(self: *const LabeledSpan) usize {
        return self.span_.length;
    }
    pub fn isEmpty(self: *const LabeledSpan) bool {
        return self.span_.length == 0;
    }
    pub fn primary(self: *const LabeledSpan) bool {
        return self.primary_;
    }

    pub fn jsonStringify(self: LabeledSpan, jw: anytype) !void {
        try jw.beginObject();
        if (self.label_) |lbl| {
            try jw.objectField("label");
            try jw.write(lbl);
        }
        try jw.objectField("span");
        try jw.write(self.span_);
        try jw.objectField("primary");
        try jw.write(self.primary_);
        try jw.endObject();
    }

    pub fn format(self: LabeledSpan, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        if (self.label_) |lbl| try writer.print("{s}@{any}", .{ lbl, self.span_ }) else try writer.print("@{any}", .{self.span_});
        if (self.primary_) try writer.writeAll(" primary");
    }
};

pub const SpanContents = struct {
    data_: []const u8,
    span_: SourceSpan,
    name_: ?[]const u8 = null,
    line_: usize = 1,
    column_: usize = 1,
    line_count_: usize = 1,
    language_: ?[]const u8 = null,

    pub fn data(self: *const SpanContents) []const u8 {
        return self.data_;
    }
    pub fn span(self: *const SpanContents) *const SourceSpan {
        return &self.span_;
    }
    pub fn name(self: *const SpanContents) ?[]const u8 {
        return self.name_;
    }
    pub fn line(self: *const SpanContents) usize {
        return self.line_;
    }
    pub fn column(self: *const SpanContents) usize {
        return self.column_;
    }
    pub fn lineCount(self: *const SpanContents) usize {
        return self.line_count_;
    }
    pub fn language(self: *const SpanContents) ?[]const u8 {
        return self.language_;
    }
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
