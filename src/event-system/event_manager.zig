const std = @import("std");

const WindowEvents = @import("events/window_events.zig").WindowEvents;
const RenderEvents = @import("events/render_events.zig").RenderEvents;

pub const EventManager = struct {
    arena: std.heap.ArenaAllocator,

    window_events: *WindowEvents,
    render_events: *RenderEvents,

    pub fn init() !EventManager {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

        // Allocate events
        const window_events_ptr = try arena.allocator().create(WindowEvents);
        window_events_ptr.* = try WindowEvents.init(&arena);

        const render_events_ptr = try arena.allocator().create(RenderEvents);
        render_events_ptr.* = try RenderEvents.init(&arena);

        return EventManager{
            .arena = arena,
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

pub var event_manager: ?*EventManager = null;

pub fn getEventManager() !*EventManager {
    if (event_manager) |em| return em;

    // allocate EventManager arena
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const em_instance = try arena.allocator().create(EventManager);
    em_instance.* = try EventManager.init();

    event_manager = em_instance;
    return em_instance;
}
