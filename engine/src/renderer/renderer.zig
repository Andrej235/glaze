const std = @import("std");

const Platform = @import("../utils/platform.zig");
const Window = @import("window.zig").Window;

const platform_renderer = verify_platform_renderer(switch (Platform.current_platform) {
    .linux => @import("../platform/linux/linux.zig").Linux,
    .windows => @import("../platform/windows.zig"),
    else => @compileError("Unsupported platform"),
});

pub const Renderer = struct {
    window: *Window,

    pub fn init() !Renderer {
        std.debug.print("Initializing renderer\n", .{});
        return Renderer{ .window = try platform_renderer.init() };
    }

    pub fn deinit(self: *Renderer) void {
        self.window.deinit();
    }
};

fn verify_platform_renderer(comptime renderer: type) type {
    if (!@hasDecl(renderer, "init_window"))
        @compileError("Platform implementation missing init_window()");

    const fn_info = @typeInfo(@TypeOf(renderer.init_window)).@"fn";
    if (fn_info.return_type != anyerror!*Window)
        @compileError("Platform implementation's init_window() has incorrect return type");

    return struct {
        pub fn init() !*Window {
            return renderer.init_window();
        }
    };
}
