const std = @import("std");

const Renderer = @import("renderer/renderer.zig").Renderer;

pub fn main() !void {
    _ = Renderer.init() catch {
        std.log.err("Failed to initialize renderer", .{});
        return;
    };
}
