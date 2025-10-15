const std = @import("std");

const FpsCounter = @import("fps-counter.zig").FpsCounter;

var fps_counter: ?*FpsCounter = null;

pub const Debug = struct {
    pub fn toggleFpsLogging() void {
        if (fps_counter) |_| {
            fps_counter = null;
            std.debug.print("Fps counter disabled\n", .{});
        } else {
            fps_counter = FpsCounter.init() catch return;
        }
    }
};
