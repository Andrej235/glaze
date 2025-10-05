const std = @import("std");

const dynString = @import("utils/dyn_string.zig");
const DynString = dynString.DynString;
const CError = dynString.CError;

const Window = @import("ui/window.zig").Window;
const KeyCode = @import("event-system/models/key_code.zig").KeyCode;
const WindowSize = @import("event-system/models/window_size.zig").WindowSize;
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

    try window_events.registerOnKeyPressed(movePlayer);
    try window_events.registerOnWindowClose(doSomeWorkWhenWindowIsClosing);
    try window_events.registerOnWindowResize(doSomeWorkWhenWindowIsResized);
    // =================================================================================================

    try w_instance.initPlatformWindow("GG", 800, 800);
    try w_instance.show();
    try w_instance.run();
}

fn movePlayer(key: KeyCode) !void {
    if (key == KeyCode.A) {
        std.debug.print("Moving left\n", .{});
    } else if (key == KeyCode.D) {
        std.debug.print("Moving right\n", .{});
    } else if (key == KeyCode.W) {
        std.debug.print("Moving up\n", .{});
    } else if (key == KeyCode.S) {
        std.debug.print("Moving down\n", .{});
    }
}

fn doSomeWorkWhenWindowIsClosing(_: void) !void {
    std.debug.print("Trala trala trala\n", .{});
    std.debug.print("Window is closing", .{});
}

fn doSomeWorkWhenWindowIsResized(size: WindowSize) !void {
    std.debug.print("Window is resized to {d}x{d}\n", .{ size.width, size.height });
    std.debug.print("Window state is {d}\n", .{size.window_state});
}
