const std = @import("std");

const window_events = @import("events/window_events.zig");

pub const EventManager = struct {
    arena: std.heap.ArenaAllocator,
    window_events: window_events.WindowEvents,

    pub fn init() !EventManager {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        return EventManager{
            .arena = arena,
            .window_events = try window_events.WindowEvents.init(&arena),
        };
    }
};

/// Global event manager
pub var event_manager: ?*EventManager = null;

pub fn getEventManager() !*EventManager {
    if (event_manager) |em| return em;

    // allocate EventManager on heap or arena
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const em_instance = try arena.allocator().create(EventManager);
    em_instance.* = try EventManager.init();

    event_manager = em_instance;
    return em_instance;
}
