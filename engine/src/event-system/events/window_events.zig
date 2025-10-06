const std = @import("std");

const KeyCode = @import("../models/key_code.zig").KeyCode;
const WindowSize = @import("../models/window_size.zig").WindowSize;
const MousePosition = @import("../models/mouse_position.zig").MousePosition;
const EventDispatcher = @import("../event_dispatcher.zig").EventDispatcher;

const EmptyDispatcherFn = *const fn (void, ?*anyopaque) anyerror!void;
const KeyPressedDispetcherFn = *const fn (KeyCode, ?*anyopaque) anyerror!void;
const WindowResizeDispatcherFn = *const fn (WindowSize, ?*anyopaque) anyerror!void;
const MouseMoveDispatcherFn = *const fn (MousePosition, ?*anyopaque) anyerror!void;

pub const WindowEvents = struct {
    allocator: *std.heap.ArenaAllocator,

    on_key_pressed: *EventDispatcher(KeyCode, *anyopaque),
    on_window_close: *EventDispatcher(void, *anyopaque),
    on_window_destroy: *EventDispatcher(void, *anyopaque),
    on_window_resize: *EventDispatcher(WindowSize, *anyopaque),
    on_mouse_move: *EventDispatcher(MousePosition, *anyopaque),
    on_window_focus_gain: *EventDispatcher(void, *anyopaque),
    on_window_focus_lose: *EventDispatcher(void, *anyopaque),

    pub fn init(allocator: *std.heap.ArenaAllocator) !WindowEvents {
        return WindowEvents{
            .allocator = allocator,
            .on_key_pressed = try createDispatcher(KeyCode, *anyopaque, allocator),
            .on_window_close = try createDispatcher(void, *anyopaque, allocator),
            .on_window_destroy = try createDispatcher(void, *anyopaque, allocator),
            .on_window_resize = try createDispatcher(WindowSize, *anyopaque, allocator),
            .on_mouse_move = try createDispatcher(MousePosition, *anyopaque, allocator),
            .on_window_focus_gain = try createDispatcher(void, *anyopaque, allocator),
            .on_window_focus_lose = try createDispatcher(void, *anyopaque, allocator),
        };
    }

    fn createDispatcher(comptime TEventArg: type, comptime TEventData: type, allocator: *std.heap.ArenaAllocator) !*EventDispatcher(TEventArg, TEventData) {
        const ptr = try allocator.allocator().create(EventDispatcher(TEventArg, TEventData));
        ptr.* = try EventDispatcher(TEventArg, TEventData).init(allocator);
        return ptr;
    }

    // --------------------------- REGISTER --------------------------- //
    pub fn registerOnKeyPressed(self: *WindowEvents, fun: KeyPressedDispetcherFn, data: ?*anyopaque) !void {
        try self.on_key_pressed.addHandler(fun, data);
    }

    pub fn registerOnWindowClose(self: *WindowEvents, fun: EmptyDispatcherFn, data: ?*anyopaque) !void {
        try self.on_window_close.addHandler(fun, data);
    }

    pub fn registerOnWindowDestroy(self: *WindowEvents, fun: EmptyDispatcherFn, data: ?*anyopaque) !void {
        try self.on_window_destroy.addHandler(fun, data);
    }

    pub fn registerOnWindowResize(self: *WindowEvents, fun: WindowResizeDispatcherFn, data: ?*anyopaque) !void {
        try self.on_window_resize.addHandler(fun, data);
    }

    pub fn registerOnMouseMove(self: *WindowEvents, fun: MouseMoveDispatcherFn, data: ?*anyopaque) !void {
        try self.on_mouse_move.addHandler(fun, data);
    }

    pub fn registerOnWindowFocusGain(self: *WindowEvents, fun: EmptyDispatcherFn, data: ?*anyopaque) !void {
        try self.on_window_focus_gain.addHandler(fun, data);
    }

    pub fn registerOnWindowFocusLose(self: *WindowEvents, fun: EmptyDispatcherFn, data: ?*anyopaque) !void {
        try self.on_window_focus_lose.addHandler(fun, data);
    }

    // --------------------------- UNREGISTER --------------------------- //
    pub fn unregisterOnKeyPressed(self: *WindowEvents, fun: KeyPressedDispetcherFn, data: ?*anyopaque) !void {
        try self.on_key_pressed.removeHandler(fun, data);
    }

    pub fn unregisterOnWindowClose(self: *WindowEvents, fun: EmptyDispatcherFn, data: ?*anyopaque) !void {
        try self.on_window_close.removeHandler(fun, data);
    }

    pub fn unregisterOnWindowDestroy(self: *WindowEvents, fun: EmptyDispatcherFn, data: ?*anyopaque) !void {
        try self.on_window_destroy.removeHandler(fun, data);
    }

    pub fn unregisterOnWindowResize(self: *WindowEvents, fun: WindowResizeDispatcherFn, data: ?*anyopaque) !void {
        try self.on_window_resize.removeHandler(fun, data);
    }

    pub fn unregisterOnMouseMove(self: *WindowEvents, fun: MouseMoveDispatcherFn, data: ?*anyopaque) !void {
        try self.on_mouse_move.removeHandler(fun, data);
    }

    pub fn unregisterOnWindowFocusGain(self: *WindowEvents, fun: EmptyDispatcherFn, data: ?*anyopaque) !void {
        try self.on_window_focus_gain.removeHandler(fun, data);
    }

    pub fn unregisterOnWindowFocusLose(self: *WindowEvents, fun: EmptyDispatcherFn, data: ?*anyopaque) !void {
        try self.on_window_focus_lose.removeHandler(fun, data);
    }
};
