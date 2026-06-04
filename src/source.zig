const std = @import("std");
const span = @import("span.zig");

pub const SourceCode = struct {
    ptr: *const anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        readSpan: *const fn (*const anyopaque, *const span.SourceSpan, usize, usize) anyerror!span.SpanContents,
    };

    pub fn readSpan(self: *const SourceCode, s: *const span.SourceSpan, before: usize, after: usize) anyerror!span.SpanContents {
        return self.vtable.readSpan(self.ptr, s, before, after);
    }
};

pub const SliceSource = struct {
    data: []const u8,
    pub fn source(self: *const SliceSource) SourceCode {
        return .{ .ptr = self, .vtable = &slice_vtable };
    }
};

fn sliceRead(ptr: *const anyopaque, s: *const span.SourceSpan, _: usize, _: usize) anyerror!span.SpanContents {
    const self: *const SliceSource = @ptrCast(@alignCast(ptr));
    return buildContents(self.data, null, s.*, null);
}

const slice_vtable = SourceCode.VTable{ .readSpan = sliceRead };

pub const NamedSource = struct {
    name: []const u8,
    data: []const u8,
    pub fn source(self: *const NamedSource) SourceCode {
        return .{ .ptr = self, .vtable = &named_vtable };
    }
};

fn namedRead(ptr: *const anyopaque, s: *const span.SourceSpan, before: usize, after: usize) anyerror!span.SpanContents {
    _ = before;
    _ = after;
    const self: *const NamedSource = @ptrCast(@alignCast(ptr));
    return buildContents(self.data, self.name, s.*, null);
}

const named_vtable = SourceCode.VTable{ .readSpan = namedRead };

fn buildContents(data: []const u8, name: ?[]const u8, sp: span.SourceSpan, language: ?[]const u8) span.SpanContents {
    var line: usize = 1;
    var column: usize = 1;
    var i: usize = 0;
    while (i < @min(sp.offset, data.len)) : (i += 1) {
        if (data[i] == '\n') {
            line += 1;
            column = 1;
        } else {
            column += 1;
        }
    }
    var line_count: usize = 1;
    var j = sp.offset;
    const end = @min(data.len, sp.offset + sp.length);
    while (j < end) : (j += 1) {
        if (data[j] == '\n') line_count += 1;
    }
    return .{ ._data = data, ._span = sp, ._name = name, ._line = line, ._column = column, ._line_count = line_count, ._language = language };
}

test "source missing and multiline" {
    const tmp = NamedSource{ .name = "file.zig", .data = "one\ntwo\nthree" };
    const src = tmp.source();
    const c = try src.readSpan(&.{ .offset = 4, .length = 3 }, 1, 1);
    try std.testing.expectEqualStrings("file.zig", c.name().?);
    try std.testing.expectEqual(@as(usize, 2), c.line());
    try std.testing.expectEqual(@as(usize, 1), c.column());
}

test "source span math" {
    const tmp = SliceSource{ .data = "a\nbc\ndef" };
    const src = tmp.source();
    const c = try src.readSpan(&.{ .offset = 2, .length = 2 }, 0, 0);
    try std.testing.expectEqual(@as(usize, 2), c.line());
    try std.testing.expectEqual(@as(usize, 1), c.column());
}
