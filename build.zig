const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "cart",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .wasm32,
                .os_tag = .freestanding,
            }),
            .optimize = optimize,
        }),
    });

    exe.entry = .disabled;
    exe.root_module.export_symbol_names = &[_][]const u8{ "start", "update" };
    exe.import_memory = true;
    exe.initial_memory = 65536;
    exe.max_memory = 65536;
    exe.stack_size = 14752;

    b.installArtifact(exe);

    const run_exe = b.addSystemCommand(&.{ "w4", "run-native" });
    run_exe.addArtifactArg(exe);

    const step_run = b.step("run", "compile and run the cart");
    step_run.dependOn(&run_exe.step);

    const viewer = b.addExecutable(.{
        .name = "dungeon-viewer",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/dungeon_viewer.zig"),
            .target = b.standardTargetOptions(.{}),
            .optimize = optimize,
        }),
    });
    b.installArtifact(viewer);

    const run_viewer = b.addRunArtifact(viewer);
    if (b.args) |args| run_viewer.addArgs(args);

    const step_viewer = b.step("run-viewer", "generate a dungeon and print it as text (optional: seed)");
    step_viewer.dependOn(&run_viewer.step);
}
