// ****************************************************************
// IMPORTS
// ****************************************************************
const std = @import("std");

const EventDispatcher = @import("../event_dispatcher.zig").EventDispatcher;
const KeyCode = @import("../models/key_code.zig").KeyCode;
const WindowSize = @import("../models/window_size.zig").WindowSize;

// ****************************************************************
// TYPES
// ****************************************************************
const EmptyDispatcherFn = *const fn (void) anyerror!void;
const KeyPressedDispetcherFn = *const fn (KeyCode) anyerror!void;
const WindowResizeDispatcherFn = *const fn (WindowSize) anyerror!void;

// ****************************************************************
// MAIN
// ****************************************************************
pub const WindowEvents = struct {
    allocator: *std.heap.ArenaAllocator,

    on_key_pressed: *EventDispatcher(KeyCode),
    on_window_close: *EventDispatcher(void),
    on_window_destroy: *EventDispatcher(void),
    on_window_resize: *EventDispatcher(WindowSize),

    pub fn init(allocator: *std.heap.ArenaAllocator) !WindowEvents {
        return WindowEvents{
            .allocator = allocator,
            .on_key_pressed = try createDispatcher(KeyCode, allocator),
            .on_window_close = try createDispatcher(void, allocator),
            .on_window_destroy = try createDispatcher(void, allocator),
            .on_window_resize = try createDispatcher(WindowSize, allocator),
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

    pub fn registerOnWindowResize(self: *WindowEvents, handler: WindowResizeDispatcherFn) !void {
        try self.on_window_resize.addHandler(handler);
    }
};
