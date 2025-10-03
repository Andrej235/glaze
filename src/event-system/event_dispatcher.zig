const std = @import("std");
const c = @cImport({
    @cInclude("windows.h");
});

// ****************************************************************
// MAIN
// ****************************************************************
pub fn EventDispatcher(comptime T: type) type {
    return struct {
        pub const HandlerFn = *const fn (T) anyerror!void;

        allocator: *std.heap.ArenaAllocator,
        handlers: std.ArrayList(*const fn (T) anyerror!void),

        pub fn init(allocator: *std.heap.ArenaAllocator) !EventDispatcher(T) {
            return EventDispatcher(T){
                .allocator = allocator,
                .handlers = try std.ArrayList(*const fn (T) anyerror!void).initCapacity(allocator.allocator(), 1),
            };
        }

        pub fn deinit(self: *EventDispatcher(T)) void {
            self.handlers.deinit();
        }

        pub fn addHandler(self: *EventDispatcher(T), handler: *const fn (T) anyerror!void) !void {
            try self.handlers.append(self.allocator.allocator(), handler);
        }

        pub fn dispatch(self: *EventDispatcher(T), event: T) anyerror!void {
            for (self.handlers.items) |h| {
                try h(event);
            }
        }
    };
}
