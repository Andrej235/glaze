const std = @import("std");

const App = @import("../app.zig").App;
const WindowEvents = @import("events/window_events.zig").WindowEvents;
const RenderEvents = @import("events/render_events.zig").RenderEvents;

pub const EventManager = struct {
    arena_allocator: *std.heap.ArenaAllocator,

    app: *App,
    window_events: *WindowEvents,
    render_events: *RenderEvents,

    pub fn create(arena_allocator: *std.heap.ArenaAllocator, app: *App) !EventManager {
        // Allocate events
        const window_events_ptr = try arena_allocator.allocator().create(WindowEvents);
        window_events_ptr.* = try WindowEvents.init(arena_allocator);

        const render_events_ptr = try arena_allocator.allocator().create(RenderEvents);
        render_events_ptr.* = try RenderEvents.init(arena_allocator);

        return EventManager{
            .arena_allocator = arena_allocator,
            .app = app,
            .window_events = window_events_ptr,
            .render_events = render_events_ptr,
        };
    }

    pub fn getWindowEvents(self: *EventManager) *WindowEvents {
        return self.window_events;
    }

    pub fn getRenderEvents(self: *EventManager) *RenderEvents {
        return self.render_events;
    }
};