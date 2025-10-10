const std = @import("std");
const c = @cImport({
    @cInclude("windows.h");
});

pub const HighResTimer = struct {
    frequency: i64,
    last_counter: i64,

    pub fn init() HighResTimer {
        var freq: c.LARGE_INTEGER = undefined;
        _ = c.QueryPerformanceFrequency(&freq);

        var counter: c.LARGE_INTEGER = undefined;
        _ = c.QueryPerformanceCounter(&counter);

        return HighResTimer{
            .frequency = freq.QuadPart,
            .last_counter = counter.QuadPart,
        };
    }

    pub fn deltaMilliseconds(self: *HighResTimer) f64 {
        var current: c.LARGE_INTEGER = undefined;
        _ = c.QueryPerformanceCounter(&current);

        const delta_counts = current.QuadPart - self.last_counter;
        self.last_counter = current.QuadPart;

        return (@as(f64, @floatFromInt(delta_counts)) * 1000.0) /
            @as(f64, @floatFromInt(self.frequency));
    }
};
