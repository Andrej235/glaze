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

    on_key_pressed: *EventDispatcher(KeyCode),
    on_window_close: *EventDispatcher(void),
    on_window_destroy: *EventDispatcher(void),
    on_window_resize: *EventDispatcher(WindowSize),
    on_mouse_move: *EventDispatcher(MousePosition),
    on_window_focus_gain: *EventDispatcher(void),
    on_window_focus_lose: *EventDispatcher(void),

    pub fn init(allocator: *std.heap.ArenaAllocator) !WindowEvents {
        return WindowEvents{
            .allocator = allocator,
            .on_key_pressed = try createDispatcher(KeyCode, allocator),
            .on_window_close = try createDispatcher(void, allocator),
            .on_window_destroy = try createDispatcher(void, allocator),
            .on_window_resize = try createDispatcher(WindowSize, allocator),
            .on_mouse_move = try createDispatcher(MousePosition, allocator),
            .on_window_focus_gain = try createDispatcher(void, allocator),
            .on_window_focus_lose = try createDispatcher(void, allocator),
        };
    }

    fn createDispatcher(comptime T: type, allocator: *std.heap.ArenaAllocator) !*EventDispatcher(T) {
        const ptr = try allocator.allocator().create(EventDispatcher(T));
        ptr.* = try EventDispatcher(T).init(allocator);
        return ptr;
    }

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
};
