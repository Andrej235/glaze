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
        destroy_allocator_on_deinit: bool = false,

        pub fn init(allocator: *std.heap.ArenaAllocator) !EventDispatcher(TEventArg, TEventData) {
            return EventDispatcher(TEventArg, TEventData){
                .allocator = allocator,
                .handlers = try std.ArrayList(HandlerEntry(TEventArg, TEventData)).initCapacity(allocator.allocator(), 1),
            };
        }

        pub fn new() !EventDispatcher(TEventArg, TEventData) {
            const arena_allocator: *std.heap.ArenaAllocator = try std.heap.page_allocator.create(std.heap.ArenaAllocator);
            arena_allocator.* = std.heap.ArenaAllocator.init(std.heap.page_allocator);

            const ed = try init(arena_allocator, true);
            ed.destroy_allocator_on_deinit = true;
            return ed;
        }

        pub fn deinit(self: *EventDispatcher(TEventArg, TEventData)) void {
            self.handlers.deinit();
        }

        pub fn addHandler(self: *EventDispatcher(TEventArg, TEventData), handler: HandlerFn(TEventArg, TEventData), data: ?TEventData) !void {
            try self.handlers.append(
                self.allocator.allocator(),
                HandlerEntry(TEventArg, TEventData){ .callback = handler, .data = data },
            );
        }

        pub fn removeHandler(self: *EventDispatcher(TEventArg, TEventData), handler: HandlerFn(TEventArg, TEventData), data: ?TEventData) !void {
            var found_index: ?usize = null;

            for (self.handlers.items, 0..) |entry, i| {
                if (entry.callback == handler and entry.data == data) {
                    found_index = i;
                    break;
                }
            }

            if (found_index) |i| {
                _ = self.handlers.swapRemove(i);
            }
        }

        pub fn dispatch(self: *EventDispatcher(TEventArg, TEventData), event: TEventArg) anyerror!void {
            for (self.handlers.items) |entry| {
                try entry.callback(event, entry.data);
            }
        }
    };
}
