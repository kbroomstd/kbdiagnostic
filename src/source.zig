const std = @import("std");
const span = @import("span.zig");

pub const SourceCode = @This();
ptr: *const anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    readSpan: *const fn (*const anyopaque, *const span.SourceSpan, usize, usize) anyerror!span.SpanContents,
};

pub fn implBy(impl_obj: anytype) SourceCode {
    const delegate = SourceCodeDelegate(impl_obj);
    return .{
        .ptr = impl_obj,
        .vtable = &.{
            .readSpan = delegate.readSpan,
        },
    };
}

pub fn readSpan(self: *const SourceCode, s: *const span.SourceSpan, before: usize, after: usize) anyerror!span.SpanContents {
    return self.vtable.readSpan(self.ptr, s, before, after);
}

pub const SliceSource = struct {
    data: []const u8,
    pub fn implBy(self: *const SliceSource) SourceCode {
        return SourceCode.implBy(self);
    }

    pub fn source(self: *const SliceSource) SourceCode {
        return self.implBy();
    }

    fn readSpan(self: *const SliceSource, s: *const span.SourceSpan, _: usize, _: usize) anyerror!span.SpanContents {
        return buildContents(self.data, null, s.*, null);
    }
};

pub const NamedSource = struct {
    const Self = @This();
    name: []const u8,
    data: []const u8,

    fn readSpan(self: *const Self, s: *const span.SourceSpan, _: usize, _: usize) anyerror!span.SpanContents {
        return buildContents(self.data, self.name, s.*, null);
    }

    pub fn implBy(self: *const Self) SourceCode {
        return SourceCode.implBy(self);
    }

    pub fn source(self: *const Self) SourceCode {
        return self.implBy();
    }
};

inline fn SourceCodeDelegate(impl_obj: anytype) type {
    const ImplType = ImplChild(@TypeOf(impl_obj));
    const ImplPtrType = @TypeOf(impl_obj);
    return struct {
        fn readSpan(impl: *const anyopaque, s: *const span.SourceSpan, before: usize, after: usize) anyerror!span.SpanContents {
            const obj = TPtr(ImplPtrType, impl);
            if (@hasDecl(ImplType, "readSpan")) return obj.readSpan(s, before, after);
            return @field(obj, "readSpan")(s, before, after);
        }
    };
}

fn TPtr(T: type, opaque_ptr: *const anyopaque) T {
    return @as(T, @ptrFromInt(@intFromPtr(opaque_ptr)));
}

fn ImplChild(T: type) type {
    return switch (@typeInfo(T)) {
        .pointer => |p| p.child,
        else => T,
    };
}

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
    return .{ .data_ = data, .span_ = sp, .name_ = name, .line_ = line, .column_ = column, .line_count_ = line_count, .language_ = language };
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
