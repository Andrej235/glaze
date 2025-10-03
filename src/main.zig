const std = @import("std");

const dynString = @import("utils/dyn_string.zig");
const DynString = dynString.DynString;
const CError = dynString.CError;

const window = @import("ui/window.zig");
const Window = window.Window;

const eventDispatcher = @import("event-system/event_dispatcher.zig");
const EventDispatcher = eventDispatcher.EventDispatcher;

const event_manager = @import("event-system/event_manager.zig");
const EventManager = event_manager.EventManager;

const key_code = @import("event-system/models/key_code.zig");
const KeyCode = key_code.KeyCode;

pub fn main() !void {
    const window_events = (try event_manager.getEventManager()).getWindowEvents();
    const i_window: *Window = try Window.init("GG", 500, 500);

    try window_events.registerOnKeyPressed(movePlayer);
    try window_events.registerOnWindowClose(doSomeWorkWhenWindowIsClosing);

    i_window.show();
    i_window.run();
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
