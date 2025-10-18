const std = @import("std");

pub const Timer = struct {
    start_time_ms: i128,
    name: []const u8,

    pub fn init(name: []const u8) Timer {
        return Timer{
            .start_time_ms = std.time.nanoTimestamp(),
            .name = name,
        };
    }

    pub fn restart(self: *Timer) void {
        self.start_time_ms = std.time.nanoTimestamp();
    }

    pub fn end(self: *const Timer) void {
        const end_time_ns = std.time.nanoTimestamp();
        const duration_ns = @as(f128, @floatFromInt(end_time_ns - self.start_time_ms));

        // The whitespace at the end of the format string is there to overwrite anything leftover from the fps counter
        if (duration_ns < 1_000) {
            std.debug.print("{s}: {d:3} ns          \n", .{ self.name, duration_ns });
        } else if (duration_ns < 1_000_000) {
            std.debug.print("{s}: {d:5.2} µs            \n", .{ self.name, duration_ns / 1_000 });
        } else if (duration_ns < 1_000_000_000) {
            std.debug.print("{s}: {d:5.2} ms            \n", .{ self.name, duration_ns / 1_000_000 });
        } else {
            std.debug.print("{s}: {d:5.2} s         \n", .{ self.name, duration_ns / 1_000_000_000 });
        }
    }
};
