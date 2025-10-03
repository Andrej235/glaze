const std = @import("std");

const dynString = @import("utils/dyn_string.zig");
const DynString = dynString.DynString;
const CError = dynString.CError;

const window = @import("ui/window.zig");
const Window = window.Window;

const eventDispatcher = @import("utils/event_dispatcher.zig");
const EventDispatcher = eventDispatcher.EventDispatcher;
const KeyCode = eventDispatcher.KeyCode;

pub fn main() !void {
    const keyboard_dispatcher: *EventDispatcher(KeyCode) = @constCast(&(try EventDispatcher(KeyCode).init(std.heap.page_allocator)));
    const i_window: *Window = try Window.init(keyboard_dispatcher, "GG", 500, 500);

    try keyboard_dispatcher.addHandler(movePlayer);

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
