const std = @import("std");
const c = @cImport({
    @cInclude("windows.h");
});

fn HandlerFn(comptime TEventArg: type, comptime TEventData: type) type {
    return *const fn (TEventArg, ?TEventData) anyerror!void;
}

fn HandlerEntry(comptime TEventArg: type, comptime TEventData: type) type {
    return struct {
        callback: HandlerFn(TEventArg, TEventData),
        data: ?TEventData,
    };
}

pub fn EventDispatcher(comptime TEventArg: type, comptime TEventData: type) type {
    return struct {
        allocator: *std.heap.ArenaAllocator,
        handlers: std.ArrayList(HandlerEntry(TEventArg, TEventData)),

        pub fn init(allocator: *std.heap.ArenaAllocator) !EventDispatcher(TEventArg, TEventData) {
            return EventDispatcher(TEventArg, TEventData){
                .allocator = allocator,
                .handlers = try std.ArrayList(HandlerEntry(TEventArg, TEventData)).initCapacity(allocator.allocator(), 1),
            };
        }

        pub fn deinit(self: *EventDispatcher(TEventArg, TEventData)) void {
            self.handlers.deinit();
        }

        pub fn addHandler(self: *EventDispatcher(TEventArg, TEventData), handler: HandlerFn(TEventArg, TEventData), data: ?TEventData) !void {
            try self.handlers.append(
                self.allocator.allocator(), 
                HandlerEntry(TEventArg, TEventData){ .callback = handler, .data = data }
            );
        }

        pub fn removeHandler(self: *EventDispatcher(TEventArg, TEventData), handler: HandlerFn(TEventArg, TEventData), data: ?TEventData) !void {
            // Try to find handler
            var index: usize = 0;
            var h: ?HandlerFn(TEventArg, TEventData) = null;
            
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

        pub fn dispatch(self: *EventDispatcher(TEventArg, TEventData), event: TEventArg) anyerror!void {
            for (self.handlers.items) |entry| {
                try entry.callback(event, entry.data);
            }
        }
    };
}