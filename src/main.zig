const std = @import("std");

const dynString = @import("utils/dyn_string.zig");
const DynString = dynString.DynString;
const CError = dynString.CError;

const Window = @import("ui/window.zig").Window;
const KeyCode = @import("event-system/models/key_code.zig").KeyCode;
const WindowSize = @import("event-system/models/window_size.zig").WindowSize;
const MousePosition = @import("event-system/models/mouse_position.zig").MousePosition;
const EventDispatcher = @import("event-system/event_dispatcher.zig").EventDispatcher;

const event_manager = @import("event-system/event_manager.zig");
const EventManager = event_manager.EventManager;

pub fn main() !void {
    // Create window instance
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const w_instance = try arena.allocator().create(Window);
    w_instance.* = try Window.init(&arena);

    // Register window events =========================================================================
    const window_events = (try event_manager.getEventManager()).getWindowEvents();
    try window_events.registerOnWindowFocusGain(windowFocusGained);
    try window_events.registerOnWindowFocusLose(windowFocusLost);
    // =================================================================================================

    try w_instance.initPlatformWindow("GG", 800, 800);
    try w_instance.show();
    try w_instance.run();
}

fn windowFocusGained(_: void) !void {
    std.debug.print("Focus Gained", .{});
}

fn windowFocusLost(_: void) !void {
    std.debug.print("Focus Lost", .{});
}
