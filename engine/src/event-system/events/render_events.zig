const std = @import("std");

const KeyCode = @import("../models/key_code.zig").KeyCode;
const WindowSize = @import("../models/window_size.zig").WindowSize;
const MousePosition = @import("../models/mouse_position.zig").MousePosition;
const EventDispatcher = @import("../event_dispatcher.zig").EventDispatcher;

const EmptyDispatcherFn = *const fn (void, ?*anyopaque) anyerror!void;
const UpdateDispatcherFn = *const fn (f64, ?*anyopaque) anyerror!void;

pub const RenderEvents = struct {
    on_render: *EventDispatcher(void, *anyopaque),
    on_update: *EventDispatcher(f64, *anyopaque),
    on_post_render: *EventDispatcher(f64, *anyopaque),

    pub fn init() !RenderEvents {
        return RenderEvents{
            .on_render = try EventDispatcher(void, *anyopaque).create(),
            .on_update = try EventDispatcher(f64, *anyopaque).create(),
            .on_post_render = try EventDispatcher(f64, *anyopaque).create(),
        };
    }

    // --------------------------- REGISTER --------------------------- //
    pub fn registerOnRender(self: *RenderEvents, fun: EmptyDispatcherFn, data: ?*anyopaque) !void {
        try self.on_render.addHandler(fun, data);
    }

    pub fn registerOnUpdate(self: *RenderEvents, fun: UpdateDispatcherFn, data: ?*anyopaque) !void {
        try self.on_update.addHandler(fun, data);
    }

    pub fn registerOnPostRender(self: *RenderEvents, fun: UpdateDispatcherFn, data: ?*anyopaque) !void {
        try self.on_post_render.addHandler(fun, data);
    }

    // --------------------------- UNREGISTER --------------------------- //
    pub fn unregisterOnRender(self: *RenderEvents, fun: EmptyDispatcherFn, data: ?*anyopaque) !void {
        try self.on_render.removeHandler(fun, data);
    }

    pub fn unregisterOnUpdate(self: *RenderEvents, fun: UpdateDispatcherFn, data: ?*anyopaque) !void {
        try self.on_update.removeHandler(fun, data);
    }

    pub fn unregisterOnPostRender(self: *RenderEvents, fun: UpdateDispatcherFn, data: ?*anyopaque) !void {
        try self.on_post_render.removeHandler(fun, data);
    }
};
