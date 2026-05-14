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

    const example_names = [_][]const u8{ "text_input", "checkbox", "radio", "button", "list", "spinner", "progress_bar", "divider", "label", "paragraph", "status_line", "select", "help", "settings" };
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

    const animated_feedback_check_step = b.step("check-animated_feedback", "Build the animated_feedback example");
    const animated_feedback_run_step = b.step("run-animated_feedback", "Run the animated_feedback example");

    const anim_dep = b.lazyDependency("chasen_anim", .{
        .target = target,
        .optimize = optimize,
    });
    const graphics_dep = b.lazyDependency("chasen_graphics", .{
        .target = target,
        .optimize = optimize,
    });

    if (anim_dep != null and graphics_dep != null) {
        const animated_feedback_exe = b.addExecutable(.{
            .name = "animated_feedback",
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples/animated_feedback/main.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "chasen", .module = chasen_dep.module("chasen") },
                    .{ .name = "chasen_ui", .module = mod },
                    .{ .name = "chasen_anim", .module = anim_dep.?.module("chasen_anim") },
                    .{ .name = "chasen_graphics", .module = graphics_dep.?.module("chasen_graphics") },
                },
            }),
        });

        animated_feedback_check_step.dependOn(&animated_feedback_exe.step);
        check_examples_step.dependOn(&animated_feedback_exe.step);

        const run_animated_feedback = b.addRunArtifact(animated_feedback_exe);
        animated_feedback_run_step.dependOn(&run_animated_feedback.step);
    }

    const rating_check_step = b.step("check-rating", "Build the rating example");
    const rating_run_step = b.step("run-rating", "Run the rating example");

    if (graphics_dep != null) {
        const rating_exe = b.addExecutable(.{
            .name = "rating",
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples/rating/main.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "chasen", .module = chasen_dep.module("chasen") },
                    .{ .name = "chasen_ui", .module = mod },
                    .{ .name = "chasen_graphics", .module = graphics_dep.?.module("chasen_graphics") },
                },
            }),
        });

        rating_check_step.dependOn(&rating_exe.step);
        check_examples_step.dependOn(&rating_exe.step);

        const run_rating = b.addRunArtifact(rating_exe);
        rating_run_step.dependOn(&run_rating.step);
    }

    const badge_check_step = b.step("check-badge", "Build the badge example");
    const badge_run_step = b.step("run-badge", "Run the badge example");

    if (graphics_dep != null) {
        const badge_exe = b.addExecutable(.{
            .name = "badge",
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples/badge/main.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "chasen", .module = chasen_dep.module("chasen") },
                    .{ .name = "chasen_ui", .module = mod },
                    .{ .name = "chasen_graphics", .module = graphics_dep.?.module("chasen_graphics") },
                },
            }),
        });

        badge_check_step.dependOn(&badge_exe.step);
        check_examples_step.dependOn(&badge_exe.step);

        const run_badge = b.addRunArtifact(badge_exe);
        badge_run_step.dependOn(&run_badge.step);
    }

    const alert_check_step = b.step("check-alert", "Build the alert example");
    const alert_run_step = b.step("run-alert", "Run the alert example");

    if (graphics_dep != null) {
        const alert_exe = b.addExecutable(.{
            .name = "alert",
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples/alert/main.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "chasen", .module = chasen_dep.module("chasen") },
                    .{ .name = "chasen_ui", .module = mod },
                    .{ .name = "chasen_graphics", .module = graphics_dep.?.module("chasen_graphics") },
                },
            }),
        });

        alert_check_step.dependOn(&alert_exe.step);
        check_examples_step.dependOn(&alert_exe.step);

        const run_alert = b.addRunArtifact(alert_exe);
        alert_run_step.dependOn(&run_alert.step);
    }
}
