const std = @import("std");

pub const Timer = struct {
    start_time_ms: i128,
    elapsed_time_ms: i128,
    is_running: bool,

    pub fn init() Timer {
        return Timer{
            .start_time_ms = 0,
            .elapsed_time_ms = 0,
            .is_running = false,
        };
    }

    pub fn start(self: *Timer) void {
        if (!self.is_running) {
            // Get the current time in milliseconds since the epoch
            self.start_time_ms = std.time.nanoTimestamp();
            self.is_running = true;
        }
    }

    pub fn stop(self: *Timer) void {
        if (self.is_running) {
            const now_ms = std.time.nanoTimestamp();

            self.elapsed_time_ms += now_ms - self.start_time_ms;

            self.is_running = false;
        }
    }

    pub fn getTime(self: *Timer) i128 {
        if (self.is_running) {
            const now_ms = std.time.nanoTimestamp();
            return self.elapsed_time_ms + (now_ms - self.start_time_ms);
        }

        return self.elapsed_time_ms;
    }

    pub fn reset(self: *Timer) void {
        self.start_time_ms = 0;
        self.elapsed_time_ms = 0;
        self.is_running = false;
    }
};
