const std = @import("std");
const Renderer = @import("../renderer/renderer.zig").Renderer;
const Caster = @import("../utils/caster.zig");

pub const FpsCounter = struct {
    last_time: i128 = 0,
    frame_count: u32 = 0,
    fps: f64 = 0.0,

    fn frame(_: void, self: ?*anyopaque) !void {
        const counter = try Caster.castFromNullableAnyopaque(FpsCounter, self);

        const current_time = std.time.nanoTimestamp();
        const delta_ns = current_time - counter.last_time;
        counter.frame_count += 1;

        if (delta_ns >= std.time.ns_per_s) {
            const n: f64 = @floatFromInt(std.time.ns_per_s);
            const d: f64 = @floatFromInt(delta_ns);
            const f: f64 = @floatFromInt(counter.frame_count);

            counter.fps = f * n / d;
            counter.frame_count = 0;
            counter.last_time = current_time;
        }
    }

    pub fn init() !*FpsCounter {
        const counter: *FpsCounter = try std.heap.page_allocator.create(FpsCounter);
        counter.* = FpsCounter{};

        try Renderer.subscribeToRequestFrameEvent(frame, counter);

        return counter;
    }
};
