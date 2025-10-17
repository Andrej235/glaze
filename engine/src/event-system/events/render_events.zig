const std = @import("std");

const types = @import("../../utils/types.zig");
const Deltatime = types.Deltatime;

const EntryId = @import("../event_dispatcher.zig").EntryKey;
const WindowSize = @import("../models/window_size.zig").WindowSize;
const KeyCode = @import("../../input-system/keycode/keycode.zig").KeyCode;
const MousePosition = @import("../models/mouse_position.zig").MousePosition;
const EventDispatcher = @import("../event_dispatcher.zig").EventDispatcher;
const ThreadedEventDispatcher = @import("../threaded_event_dispatcher.zig").ThreadedEventDispatcher;

const EmptyDispatcherFn = *const fn (void, ?*anyopaque) anyerror!void;
const UpdateDispatcherFn = *const fn (Deltatime, ?*anyopaque) anyerror!void;

pub const RenderEvents = struct {
    on_update: *EventDispatcher(Deltatime, *anyopaque),
    on_late_update: *EventDispatcher(Deltatime, *anyopaque),
    on_fixed_update: *EventDispatcher(Deltatime, *anyopaque),
    on_post_render: *EventDispatcher(Deltatime, *anyopaque),

    pub fn init() !RenderEvents {
        return RenderEvents{
            .on_update = try EventDispatcher(Deltatime, *anyopaque).create(),
            .on_late_update = try EventDispatcher(Deltatime, *anyopaque).create(),
            .on_fixed_update = try EventDispatcher(Deltatime, *anyopaque).create(),
            .on_post_render = try EventDispatcher(Deltatime, *anyopaque).create(),
        };
    }

    // --------------------------- REGISTER --------------------------- //
    pub fn registerOnUpdate(self: *RenderEvents, fun: UpdateDispatcherFn, data: ?*anyopaque) !EntryId {
        return try self.on_update.addHandler(fun, data);
    }

    pub fn registerOnLateUpdate(self: *RenderEvents, fun: UpdateDispatcherFn, data: ?*anyopaque) !EntryId {
        return try self.on_late_update.addHandler(fun, data);
    }

    pub fn registerOnFixedUpdate(self: *RenderEvents, fun: UpdateDispatcherFn, data: ?*anyopaque) !EntryId {
        return try self.on_fixed_update.addHandler(fun, data);
    }

    pub fn registerOnPostRender(self: *RenderEvents, fun: UpdateDispatcherFn, data: ?*anyopaque) !EntryId {
        return try self.on_post_render.addHandler(fun, data);
    }

    // --------------------------- UNREGISTER --------------------------- //
    pub fn unregisterOnUpdate(self: *RenderEvents, fun: UpdateDispatcherFn, data: ?*anyopaque) !void {
        try self.on_update.removeHandler(fun, data);
    }

    pub fn unregisterOnLateUpdate(self: *RenderEvents, fun: UpdateDispatcherFn, data: ?*anyopaque) !void {
        try self.on_late_update.removeHandler(fun, data);
    }

    pub fn unregisterOnFixedUpdate(self: *RenderEvents, fun: UpdateDispatcherFn, data: ?*anyopaque) !void {
        try self.on_fixed_update.removeHandler(fun, data);
    }

    pub fn unregisterOnPostRender(self: *RenderEvents, fun: UpdateDispatcherFn, data: ?*anyopaque) !void {
        try self.on_post_render.removeHandler(fun, data);
    }
};
