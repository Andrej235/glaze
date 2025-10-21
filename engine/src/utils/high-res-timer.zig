const std = @import("std");
const c = @cImport({
    @cInclude("windows.h");
});

const types = @import("../utils/types.zig");
const Deltatime = types.Deltatime;

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

    pub fn deltaSeconds(self: *HighResTimer) Deltatime {
        var current: c.LARGE_INTEGER = undefined;
        _ = c.QueryPerformanceCounter(&current);

        const delta_counts = current.QuadPart - self.last_counter;
        self.last_counter = current.QuadPart;

        // Convert counts to seconds
        return @as(Deltatime, @floatFromInt(delta_counts)) /
            @as(Deltatime, @floatFromInt(self.frequency));
    }
};
