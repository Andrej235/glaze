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
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "glaze", .module = mod },
            },
        }),
    });

    mod.addIncludePath(b.path("src"));
    mod.addCSourceFile(.{ .file = b.path("src/renderer/gl/glad/src/gl.c") });
    mod.link_libc = true;

    if (platform.current_platform == .windows) {
        mod.addIncludePath(b.path("src/renderer/gl/glad/include"));
        mod.linkSystemLibrary("gdi32", .{ .needed = true });
        mod.linkSystemLibrary("user32", .{ .needed = true });
        mod.linkSystemLibrary("glu32", .{ .needed = true });
        mod.linkSystemLibrary("opengl32", .{ .needed = true });

        mod.addCSourceFile(.{ .file = b.path("src/renderer/gl/glad/src/wgl.c") });
    } else if (platform.current_platform == .linux) {
        mod.linkSystemLibrary("wayland-client", .{ .needed = true });
        mod.linkSystemLibrary("wayland-egl", .{ .needed = true });
        mod.linkSystemLibrary("EGL", .{ .needed = true });
        mod.linkSystemLibrary("GLESv2", .{ .needed = true });
        mod.linkSystemLibrary("xkbcommon", .{ .needed = true });

        mod.addCSourceFile(.{ .file = b.path("src/platform/linux/xdg-shell-client-protocol.c") });
        mod.addCSourceFile(.{ .file = b.path("src/renderer/gl/glad/src/egl.c") });
    }

    const zigimg_dependency = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
    });

    mod.addImport("zigimg", zigimg_dependency.module("zigimg"));

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
