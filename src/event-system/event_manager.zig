// ****************************************************************
// IMPORTS
// ****************************************************************
const std = @import("std");

const window_events = @import("events/window_events.zig");
const WindowEvents = window_events.WindowEvents;

// ****************************************************************
// MAIN
// ****************************************************************
pub const EventManager = struct {
    arena: std.heap.ArenaAllocator,

    window_events: *WindowEvents,

    pub fn init() !EventManager {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

        // Allocate events
        const keyboard_dispatcher_ptr = try arena.allocator().create(WindowEvents);
        keyboard_dispatcher_ptr.* = try WindowEvents.init(&arena);

        return EventManager{
            .arena = arena,
            .window_events = keyboard_dispatcher_ptr,
        };
    }

    // ****************************************************************
    // Get Functions
    // ****************************************************************
    pub fn getWindowEvents(self: *EventManager) *WindowEvents {
        return self.window_events;
    }
};

// ****************************************************************
// SINGLETON
// ****************************************************************
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
