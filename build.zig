const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const chasen_dep = b.dependency("chasen", .{
        .target = target,
        .optimize = optimize,
    });

    const mod = b.addModule("chasen_ui", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "chasen", .module = chasen_dep.module("chasen") },
        },
    });

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);

    const example_names = [_][]const u8{"text_input"};
    const check_examples_step = b.step("check-examples", "Build all examples");

    for (example_names) |name| {
        const example_exe = b.addExecutable(.{
            .name = name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(b.fmt("examples/{s}/main.zig", .{name})),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "chasen", .module = chasen_dep.module("chasen") },
                    .{ .name = "chasen_ui", .module = mod },
                },
            }),
        });

        const check_example_step = b.step(
            b.fmt("check-{s}", .{name}),
            b.fmt("Build the {s} example", .{name}),
        );
        check_example_step.dependOn(&example_exe.step);
        check_examples_step.dependOn(&example_exe.step);

        const run_example = b.addRunArtifact(example_exe);
        const run_example_step = b.step(
            b.fmt("run-{s}", .{name}),
            b.fmt("Run the {s} example", .{name}),
        );
        run_example_step.dependOn(&run_example.step);
    }
}
