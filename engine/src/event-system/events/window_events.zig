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
    on_key_down: *EventDispatcher(KeyCode, *anyopaque),
    on_key_up: *EventDispatcher(KeyCode, *anyopaque),
    on_window_close: *EventDispatcher(void, *anyopaque),
    on_window_destroy: *EventDispatcher(void, *anyopaque),
    on_window_resize: *EventDispatcher(WindowSize, *anyopaque),
    on_mouse_move: *EventDispatcher(MousePosition, *anyopaque),
    on_window_focus_gain: *EventDispatcher(void, *anyopaque),
    on_window_focus_lose: *EventDispatcher(void, *anyopaque),

    pub fn init() !WindowEvents {
        return WindowEvents{
            .on_key_down = try EventDispatcher(KeyCode, *anyopaque).create(),
            .on_key_up = try EventDispatcher(KeyCode, *anyopaque).create(),
            .on_window_close = try EventDispatcher(void, *anyopaque).create(),
            .on_window_destroy = try EventDispatcher(void, *anyopaque).create(),
            .on_window_resize = try EventDispatcher(WindowSize, *anyopaque).create(),
            .on_mouse_move = try EventDispatcher(MousePosition, *anyopaque).create(),
            .on_window_focus_gain = try EventDispatcher(void, *anyopaque).create(),
            .on_window_focus_lose = try EventDispatcher(void, *anyopaque).create(),
        };
    }

    // --------------------------- REGISTER --------------------------- //
    pub fn registerOnKeyDown(self: *WindowEvents, fun: KeyPressedDispetcherFn, data: ?*anyopaque) !void {
        try self.on_key_down.addHandler(fun, data);
    }

    pub fn registerOnKeyUp(self: *WindowEvents, fun: KeyPressedDispetcherFn, data: ?*anyopaque) !void {
        try self.on_key_up.addHandler(fun, data);
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
    pub fn unregisterOnKeyDown(self: *WindowEvents, fun: KeyPressedDispetcherFn, data: ?*anyopaque) !void {
        try self.on_key_down.removeHandler(fun, data);
    }

    pub fn unregisterOnKeyUp(self: *WindowEvents, fun: KeyPressedDispetcherFn, data: ?*anyopaque) !void {
        try self.on_key_up.removeHandler(fun, data);
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
