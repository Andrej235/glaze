const std = @import("std");

const event_dispatcher = @import("../event_dispatcher.zig");
const EventDispatcher = event_dispatcher.EventDispatcher;

const key_code = @import("../models/key_code.zig");
const KeyCode = key_code.KeyCode;

pub const WindowEvents = struct {
    allocator: *std.heap.ArenaAllocator,

    keyboard_dispatcher: *EventDispatcher(KeyCode),

    pub fn init(allocator: *std.heap.ArenaAllocator) !WindowEvents {
        // allocate dispatcher on arena
        const dispatcher_ptr = try allocator.allocator().create(EventDispatcher(KeyCode));
        dispatcher_ptr.* = try EventDispatcher(KeyCode).init(allocator);

        return WindowEvents{
            .allocator = allocator,
            .keyboard_dispatcher = dispatcher_ptr,
        };
    }
};
