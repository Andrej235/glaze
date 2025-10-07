const std = @import("std");

const Platform = @import("../utils/platform.zig");
const Window = @import("window.zig").Window;

const platform_renderer = verify_platform_renderer(switch (Platform.current_platform) {
    .linux => @import("../platform/linux/linux.zig").Linux,
    .windows => @import("../platform/windows.zig"),
    else => @compileError("Unsupported platform"),
});

pub const Renderer = struct {
    window: Window,

    pub fn init() !Renderer {
        return Renderer{ .window = try platform_renderer.init() };
    }

    pub fn deinit(self: *Renderer) void {
        self.window.deinit();
    }
};

fn verify_platform_renderer(comptime renderer: type) type {
    if (!@hasDecl(renderer, "init_window")) @compileError("Platform implementation missing init_window()");

    if (@TypeOf(renderer.init_window) != fn () anyerror!Window) @compileError("Platform implementation missing function init_window()");

    return struct {
        pub fn init() !Window {
            return error.Unimplemented;
        }
    };
}
