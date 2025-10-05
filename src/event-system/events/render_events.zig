const std = @import("std");

const KeyCode = @import("../models/key_code.zig").KeyCode;
const WindowSize = @import("../models/window_size.zig").WindowSize;
const MousePosition = @import("../models/mouse_position.zig").MousePosition;
const EventDispatcher = @import("../event_dispatcher.zig").EventDispatcher;

const EmptyDispatcherFn = *const fn (void, ?*anyopaque) anyerror!void;

pub const RenderEvents = struct {
    allocator: *std.heap.ArenaAllocator,

    on_render: *EventDispatcher(void),
    on_update: *EventDispatcher(void),

    pub fn init(allocator: *std.heap.ArenaAllocator) !RenderEvents {
        return RenderEvents{
            .allocator = allocator,
            .on_render = try createDispatcher(void, allocator),
            .on_update = try createDispatcher(void, allocator),
        };
    }

    fn createDispatcher(comptime T: type, allocator: *std.heap.ArenaAllocator) !*EventDispatcher(T) {
        const ptr = try allocator.allocator().create(EventDispatcher(T));
        ptr.* = try EventDispatcher(T).init(allocator);
        return ptr;
    }

    pub fn registerOnRender(self: *RenderEvents, fun: EmptyDispatcherFn, data: ?*anyopaque) !void {
        try self.on_render.addHandler(fun, data);
    }

    pub fn registerOnUpdate(self: *RenderEvents, fun: EmptyDispatcherFn, data: ?*anyopaque) !void {
        try self.on_update.addHandler(fun, data);
    }
};