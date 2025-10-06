const std = @import("std");
const c = @cImport({
    @cInclude("windows.h");
});

fn HandlerFn(comptime T: type) type {
    return *const fn (T, ?*anyopaque) anyerror!void;
}

fn HandlerEntry(comptime T: type) type {
    return struct {
        callback: HandlerFn(T),
        data: ?*anyopaque,
    };
}

pub fn EventDispatcher(comptime T: type) type {
    return struct {
        allocator: *std.heap.ArenaAllocator,
        handlers: std.ArrayList(HandlerEntry(T)),

        pub fn init(allocator: *std.heap.ArenaAllocator) !EventDispatcher(T) {
            return EventDispatcher(T){
                .allocator = allocator,
                .handlers = try std.ArrayList(HandlerEntry(T)).initCapacity(allocator.allocator(), 1),
            };
        }

        pub fn new() EventDispatcher(T) {
            // TODO
        }

        pub fn deinit(self: *EventDispatcher(T)) void {
            self.handlers.deinit();
        }

        pub fn addHandler(self: *EventDispatcher(T), handler: HandlerFn(T), data: ?*anyopaque) !void {
            try self.handlers.append(
                self.allocator.allocator(), 
                HandlerEntry(T){ .callback = handler, .data = data }
            );
        }

        pub fn removeHandler(self: *EventDispatcher(T), handler: HandlerFn(T), data: ?*anyopaque) !void {
            // Try to find handler
            const index: usize = -1;
            var h: ?HandlerFn(T) = null;
            
            for (self.handlers.items) |entry| {
                if (entry.callback == handler and entry.data == data) {
                    h = entry.callback;
                    break;
                }

                index += 1;
            }

            // If it exists remove
            if (h) |_| {
                _ = self.handlers.swapRemove(index);
            }
        }

        pub fn dispatch(self: *EventDispatcher(T), event: T) anyerror!void {
            for (self.handlers.items) |entry| {
                try entry.callback(event, entry.data);
            }
        }
    };
}