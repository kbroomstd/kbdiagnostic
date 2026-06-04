const std = @import("std");

pub const Severity = enum { Advice, Warning, Error };

pub fn format(self: Severity, w: *std.Io.Writer) std.Io.Writer.Error!void {
    try w.writeAll(@tagName(self));
}

pub fn jsonStringify(self: Severity, jw: anytype) !void {
    try jw.write(@tagName(self));
}

test "severity values" {
    try std.testing.expect(@intFromEnum(Severity.Advice) == 0);
}

test "severity stringify and format" {
    var buf: [16]u8 = undefined;
    var w = std.Io.Writer.fixed(&buf);
    try format(.Warning, &w);
    try w.flush();
    try std.testing.expectEqualStrings("Warning", buf[0..w.end]);
    const json = try std.json.Stringify.valueAlloc(std.testing.allocator, .Error, .{});
    defer std.testing.allocator.free(json);
    try std.testing.expectEqualStrings("\"Error\"", json);
}

test "severity eql" {
    try std.testing.expect(std.meta.eql(Severity.Warning, Severity.Warning));
    try std.testing.expect(!std.meta.eql(Severity.Warning, Severity.Error));
}
