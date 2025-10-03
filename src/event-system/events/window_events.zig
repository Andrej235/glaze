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
const EmptyDispatcherFn = *const fn (void) anyerror!void;
const KeyPressedDispetcherFn = *const fn (KeyCode) anyerror!void;

// ****************************************************************
// MAIN
// ****************************************************************
pub const WindowEvents = struct {
    allocator: *std.heap.ArenaAllocator,

    on_key_pressed: *EventDispatcher(KeyCode),
    on_window_close: *EventDispatcher(void),
    on_window_destroy: *EventDispatcher(void),

    pub fn init(allocator: *std.heap.ArenaAllocator) !WindowEvents {
        return WindowEvents{
            .allocator = allocator,
            .on_key_pressed = try createDispatcher(KeyCode, allocator),
            .on_window_close = try createDispatcher(void, allocator),
            .on_window_destroy = try createDispatcher(void, allocator),
        };
    }

    pub fn createDispatcher(comptime T: type, allocator: *std.heap.ArenaAllocator) !*EventDispatcher(T) {
        const ptr = try allocator.allocator().create(EventDispatcher(T));
        ptr.* = try EventDispatcher(T).init(allocator);
        return ptr;
    }

    // ****************************************************************
    // Register Functions
    // ****************************************************************
    pub fn registerOnKeyPressed(self: *WindowEvents, handler: KeyPressedDispetcherFn) !void {
        try self.on_key_pressed.addHandler(handler);
    }

    pub fn registerOnWindowClose(self: *WindowEvents, handler: EmptyDispatcherFn) !void {
        try self.on_window_close.addHandler(handler);
    }

    pub fn registerOnWindowDestroy(self: *WindowEvents, handler: EmptyDispatcherFn) !void {
        try self.on_window_destroy.addHandler(handler);
    }
};
