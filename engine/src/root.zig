const std = @import("std");
const Debug = @import("debug/debug.zig").Debug;

const WL = @import("platform/linux/wayland.zig").Wayland;
const Renderer = @import("renderer/renderer.zig").Renderer;

pub fn main() !void {
    _ = try Renderer.init();

    while (true) {
        Debug.logFps();
        std.Thread.sleep(1_000_000_000);
    }
}
