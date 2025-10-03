const std = @import("std");
const c = @cImport({
    @cInclude("windows.h");
});

// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
// TYPES
// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
const Allocator = std.mem.Allocator;

// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
// MAIN STRUCT
// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
pub fn EventDispatcher(comptime T: type) type {
    return struct {
        allocator: Allocator,
        handlers: std.ArrayList(*const fn (T) anyerror!void),

        pub fn init(allocator: Allocator) !EventDispatcher(T) {
            return EventDispatcher(T){
                .allocator = allocator,
                .handlers = try std.ArrayList(*const fn (T) anyerror!void).initCapacity(allocator, 1),
            };
        }

        pub fn deinit(self: *EventDispatcher(T)) void {
            self.handlers.deinit();
        }

        pub fn addHandler(self: *EventDispatcher(T), handler: *const fn (T) anyerror!void) !void {
            try self.handlers.append(self.allocator, handler);
        }

        pub fn dispatch(self: *EventDispatcher(T), event: T) anyerror!void {
            for (self.handlers.items) |h| {
                try h(event);
            }
        }
    };
}

// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
// ENUMS
// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
pub const KeyCode = enum(c.WPARAM) {
    A = @intCast(0x41),
    W = @intCast(0x57),
    S = @intCast(0x53),
    D = @intCast(0x44),
    Unknown = @intCast(0),
};

pub fn keycodeFromInt(num: u32) KeyCode {
    return switch (num) {
        0x41 => KeyCode.A,
        0x57 => KeyCode.W,
        0x53 => KeyCode.S,
        0x44 => KeyCode.D,
        else => KeyCode.Unknown,
    };
}
