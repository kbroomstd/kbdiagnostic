pub fn main(init: std.process.Init) !void {
    var use_json = false;
    var args = try init.minimal.args.iterateAllocator(init.arena.allocator());
    defer args.deinit();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--json")) {
            use_json = true;
            break;
        }
    }
    const handler = if (use_json) (kb.JsonReportHandler{}).base else (kb.GraphicalReportHandler{}).base;

    var buf: [4096]u8 = undefined;
    var file_writer: std.Io.File.Writer = .init(.stdout(), init.io, &buf);
    const out = &file_writer.interface;

    for (example_basic.all) |item| {
        const d = item.diagnostic();
        try handler.display(&d, out);
        if (!use_json) try out.writeByte('\n');
    }
    try out.flush();
}

const std = @import("std");
const kb = @import("kbdiagnostics");
const example_basic = @import("./example_basic.zig");
