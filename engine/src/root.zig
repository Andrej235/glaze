const std = @import("std");
const Debug = @import("debug/debug.zig").Debug;

const WL = @import("platform/linux/wayland.zig").Wayland;
const Renderer = @import("renderer/renderer.zig").Renderer;

const App = @import("app.zig").App;

pub fn main() !void {
    // _ = try App.create();
    _ = try Renderer.init(.{
        .height = 800,
        .width = 800,
        .title = "Glaze",
    });

    while (true) {
        Debug.logFps();
        std.Thread.sleep(1_000_000_000);
    }
}
