// ****************************************************************
// IMPORTS
// ****************************************************************
const std = @import("std");

const event_dispatcher = @import("../event_dispatcher.zig");
const EventDispatcher = event_dispatcher.EventDispatcher;

const key_code = @import("../models/key_code.zig");
const KeyCode = key_code.KeyCode;

// ****************************************************************
// TYPES
// ****************************************************************
const KeyboardDispetcherFn = *const fn (KeyCode) anyerror!void;

// ****************************************************************
// MAIN
// ****************************************************************
pub const WindowEvents = struct {
    allocator: *std.heap.ArenaAllocator,

    keyboard_dispatcher: *EventDispatcher(KeyCode),

    pub fn init(allocator: *std.heap.ArenaAllocator) !WindowEvents {
        // Allocate dispatchers
        const keyboard_dispatcher_ptr = try allocator.allocator().create(EventDispatcher(KeyCode));
        keyboard_dispatcher_ptr.* = try EventDispatcher(KeyCode).init(allocator);

        return WindowEvents{
            .allocator = allocator,
            .keyboard_dispatcher = keyboard_dispatcher_ptr,
        };
    }

    // ****************************************************************
    // Register Functions
    // ****************************************************************
    pub fn registerOnKeyPressed(self: *WindowEvents, handler: KeyboardDispetcherFn) !void {
        try self.keyboard_dispatcher.addHandler(handler);
    }
};
