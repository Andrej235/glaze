const std = @import("std");
const platform = @import("src/utils/platform.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const mod = b.addModule("glaze", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "glaze",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "glaze", .module = mod },
            },
        }),
    });

    exe.addIncludePath(b.path("src"));

    if (platform.current_platform == .windows) {
        exe.linkSystemLibrary("gdi32");
        exe.linkSystemLibrary("opengl32");
    } else if (platform.current_platform == .linux) {
        exe.linkSystemLibrary("wayland-client");
        exe.linkSystemLibrary("wayland-egl");
        exe.linkSystemLibrary("EGL");
        exe.linkSystemLibrary("GLESv2");
        exe.linkSystemLibrary("xkbcommon");
        exe.linkLibC();
        exe.addCSourceFile(.{ .file = b.path("src/wayland/xdg-shell-client-protocol.c") });
    }

    exe.linkLibC();
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
