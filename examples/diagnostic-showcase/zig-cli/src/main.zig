const std = @import("std");
const kb = @import("kbdiagnostic");
const example_basic = @import("./example_basic.zig");
const example_chained = @import("./example_chained.zig");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    var use_json = false;
    var sources_dir: []const u8 = "../sources";

    var args = try init.minimal.args.iterateAllocator(arena);
    defer args.deinit();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--json")) {
            use_json = true;
        } else if (std.mem.eql(u8, arg, "--sources-dir")) {
            sources_dir = args.next() orelse return error.MissingSourcesDirArg;
        }
    }

    const handler = if (use_json) (kb.JsonReportHandler{}).base else (kb.GraphicalReportHandler{}).base;

    const source_names = [_][]const u8{ "config.yaml", "handler.go", "query.sql", "pipeline.py", "template.tera" };
    var sources: [source_names.len]kb.NamedSource = undefined;
    for (&sources, source_names) |*s, name| {
        const path = try std.fs.path.join(arena, &.{ sources_dir, name });
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, path, arena, .limited(1 << 20));
        s.* = .{ .name = name, .data = data };
    }

    var buf: [4096]u8 = undefined;
    var file_writer: std.Io.File.Writer = .init(.stdout(), init.io, &buf);
    const out = &file_writer.interface;

    for (example_basic.all) |item| {
        const d = item.diagnostic();
        try handler.display(&d, out);
        if (!use_json) try out.writeByte('\n');
    }

    const chained = try example_chained.build(arena, &sources);
    for (chained) |d| {
        try handler.display(&d, out);
        if (!use_json) try out.writeByte('\n');
    }

    try out.flush();
}
