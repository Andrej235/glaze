const std = @import("std");

const platform = @import("src/utils/platform.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const mod = b.addModule("glaze", .{
        .root_source_file = b.path("src/main.zig"),
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
    exe.addCSourceFile(.{ .file = b.path("src/renderer/gl/glad/src/gl.c") });

    if (platform.current_platform == .windows) {
        exe.addIncludePath(b.path("src/renderer/gl/glad/include"));
        exe.linkSystemLibrary("gdi32");
        exe.linkSystemLibrary("user32");
        exe.linkSystemLibrary("glu32");
        exe.linkSystemLibrary("opengl32");

        exe.addCSourceFile(.{ .file = b.path("src/renderer/gl/glad/src/wgl.c") });
    } else if (platform.current_platform == .linux) {
        exe.linkSystemLibrary("wayland-client");
        exe.linkSystemLibrary("wayland-egl");
        exe.linkSystemLibrary("EGL");
        exe.linkSystemLibrary("GLESv2");
        exe.linkSystemLibrary("xkbcommon");
        exe.linkLibC();

        exe.addCSourceFile(.{ .file = b.path("src/platform/linux/xdg-shell-client-protocol.c") });
        exe.addCSourceFile(.{ .file = b.path("src/renderer/gl/glad/src/egl.c") });
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
