const std = @import("std");

const WL = @import("platform/linux/wayland.zig").Wayland;
const Renderer = @import("renderer/renderer.zig").Renderer;

pub fn main() !void {
    _ = try Renderer.init();

    while (true) {
        std.Thread.sleep(1_000_000_000);
    }
}
