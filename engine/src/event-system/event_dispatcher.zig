const std = @import("std");

const c_allocator_util = @import("../utils/c_allocator_util.zig");
const cAlloc = c_allocator_util.cAlloc;
const cFree = c_allocator_util.cFree;

const Timer = @import("../utils/timer.zig").Timer;

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
        allocator: std.mem.Allocator, // c_allocator
        handlers: std.ArrayList(HandlerEntry(TEventArg, TEventData)),

        mutex: std.Thread.Mutex,

        /// Creates and allocates memory for event dispatcher
        pub fn create() !*EventDispatcher(TEventArg, TEventData) {
            const ptr = try cAlloc(EventDispatcher(TEventArg, TEventData));
            ptr.* = EventDispatcher(TEventArg, TEventData){
                .allocator = std.heap.c_allocator,
                .handlers = std.ArrayList(HandlerEntry(TEventArg, TEventData)){},
                .mutex = std.Thread.Mutex{},
            };

            return ptr;
        }

        /// Deallocates memory for event dispatcher
        pub fn destroy(self: *EventDispatcher(TEventArg, TEventData)) void {
            self.handlers.deinit();
            cFree(self);
        }

        pub fn addHandler(self: *EventDispatcher(TEventArg, TEventData), handler: HandlerFn(TEventArg, TEventData), data: ?TEventData) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            try self.handlers.append(
                self.allocator,
                HandlerEntry(TEventArg, TEventData){ .callback = handler, .data = data },
            );
        }

        pub fn removeHandler(self: *EventDispatcher(TEventArg, TEventData), handler: HandlerFn(TEventArg, TEventData), data: ?TEventData) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            const timer: *Timer = @constCast(&Timer.init());
            timer.start();

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

            timer.stop();
            // std.debug.print("\nRemoved in: {} ns", .{timer.getTime()});
        }

        pub fn dispatch(self: *EventDispatcher(TEventArg, TEventData), event: TEventArg) anyerror!void {
            for (self.handlers.items) |entry| {
                try entry.callback(event, entry.data);
            }
        }
    };
}
