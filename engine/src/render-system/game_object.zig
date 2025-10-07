const std = @import("std");

const caster = @import("../utils/caster.zig");
const event_manager = @import("../event-system/event_manager.zig");

const App = @import("../app.zig").App;
const Component = @import("./component.zig").Component;
const DynString = @import("../utils/dyn_string.zig").DynString;
const RenderEvents = @import("../event-system/events/render_events.zig").RenderEvents;

pub const GameObject = struct {
    arena_allocator: *std.heap.ArenaAllocator,

    app: *App,

    id: usize,
    name: *DynString,
    tag: *DynString,

    components: std.ArrayList(*Component),

    pub fn create(arena_allocator: *std.heap.ArenaAllocator, app: *App) !GameObject {
        return GameObject{
            .id = 0,
            .arena_allocator = arena_allocator,
            .app = app,
            .name = try DynString.init(),
            .tag = try DynString.init(),
            .components = std.ArrayList(*Component){},
        };
    }

    pub fn destroy(self: *GameObject) !void {
        self.name.deinit();
        self.tag.deinit();

        for (self.components.items) |component| {
            try component.destroy();
        }

        self.components.deinit(self.arena_allocator.allocator());
    }

    pub fn addComponent(self: *GameObject, comptime T: type) !void {
        const allocator = self.arena_allocator.allocator();
        
        // Create new component instance
        const new_component = try allocator.create(Component);
        new_component.* = try Component.create(self.arena_allocator, self, T);

        // Add component to game object
        try self.components.append(allocator, new_component);

        // Invoke must called component functions
        try new_component.start();
        try new_component.bindEvents();
    }

    pub fn removeComponent() !void {}

    pub fn setId(self: *GameObject, id: usize) void {
        self.id = id;
    }
};
