const std = @import("std");

const App = @import("../app.zig").App;
const Caster = @import("../utils/caster.zig");

pub const FpsCounter = struct {
    handler_id: i64 = 0,

    delta_accumulator: f64 = 0.0,
    frame_count: u32 = 0,
    fps: f64 = 0.0,

    fn frame(delta: f32, self: ?*anyopaque) !void {
        const counter = try Caster.castFromNullableAnyopaque(FpsCounter, self);

        counter.delta_accumulator += delta;
        counter.frame_count += 1;

        if (counter.delta_accumulator >= 1.0) {
            counter.fps = @as(f64, @floatFromInt(counter.frame_count)) / counter.delta_accumulator;
            counter.frame_count = 0;
            counter.delta_accumulator = 0.0;

            std.debug.print("\rfps: {:8.2}\r", .{counter.fps});
        }
    }

    pub fn init() !*FpsCounter {
        const counter: *FpsCounter = try std.heap.page_allocator.create(FpsCounter);
        counter.* = FpsCounter{};

        std.debug.print("\rfps: {:8.2}\r", .{0});
        counter.handler_id = try App.get().event_system.render_events.on_update.addHandler(frame, counter);

        return counter;
    }

    pub fn deinit(self: *FpsCounter) void {
        try App.get().event_system.render_events.on_update.removeHandlerById(self.handler_id);
        std.heap.page_allocator.destroy(self);
    }
};
