const std = @import("std");

const FpsCounter = @import("fps-counter.zig").FpsCounter;
const Timer = @import("timer.zig").Timer;

var fps_counter: ?*FpsCounter = null;

pub const Debug = struct {
    pub fn toggleFpsLogging() void {
        if (fps_counter) |c| {
            c.deinit();
            fps_counter = null;
            std.debug.print("Fps counter disabled\n", .{});
        } else {
            fps_counter = FpsCounter.init() catch return;
        }
    }

    pub fn startTimer(name: []const u8) Timer {
        return Timer.init(name);
    }
};
