const std = @import("std");
const span = @import("span.zig");

pub fn expectEqualSpan(expected: span.SourceSpan, actual: span.SourceSpan) !void {
    try std.testing.expectEqual(expected.offset, actual.offset);
    try std.testing.expectEqual(expected.length, actual.length);
}

pub fn expectEqualLabel(expected: ?[]const u8, actual: ?[]const u8) !void {
    try std.testing.expectEqual(expected, actual);
}

pub fn expectOutputContains(haystack: []const u8, needle: []const u8) !void {
    try std.testing.expect(std.mem.indexOf(u8, haystack, needle) != null);
}

pub fn expectJsonField(json: []const u8, field: []const u8) !void {
    try expectOutputContains(json, field);
}

pub fn expectEqualDiagnostic(a: anytype, b: anytype) !void {
    try std.testing.expectEqualStrings(a.message(), b.message());
}

test "helpers" {
    try expectEqualSpan(.{ .offset = 1, .length = 2 }, .{ .offset = 1, .length = 2 });
}
