const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const kb = b.addModule("kbdiagnostic", .{
        .root_source_file = b.path("../../../src/root.zig"),
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "zig-cli",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kbdiagnostic", .module = kb },
            },
        }),
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run example");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run example tests");
    test_step.dependOn(&run_exe_tests.step);
}
