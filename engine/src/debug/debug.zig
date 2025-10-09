const std = @import("std");
const FpsCounter = @import("fps-counter.zig").FpsCounter;

var fps_counter: ?*FpsCounter = null;

pub const Debug = struct {
    pub fn logFps() void {
        if (fps_counter) |counter| {
            std.debug.print("\rfps: {:.2}", .{counter.fps});
            return;
        }

        fps_counter = FpsCounter.init() catch return;
        std.debug.print("Fps counter initialized, calculating fps...\n", .{});
    }
};
