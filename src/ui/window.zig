const std = @import("std");
const builtin = @import("builtin");

const event_manager = @import("../event-system/event_manager.zig");

const App = @import("../app.zig").App;
const WindowEvents = @import("../event-system/events/window_events.zig").WindowEvents;

pub const Window = struct {
    arena_allocator: *std.heap.ArenaAllocator,

    platform_window: ?*PlatformWindow = null,

    app: *App,
    window_events: *WindowEvents,

    pub fn create(arena_allocator: *std.heap.ArenaAllocator, app: *App, window_events: *WindowEvents) !Window {
        return Window{ .arena_allocator = arena_allocator, .app = app, .window_events = window_events };
    }

    /// Initializes platform window instance because we don't have access to window instance in ini() function
    pub fn initPlatformWindow(self: *Window, window_title: []const u8, width: i16, height: i16) !void {
        const pw_instance_ptr = try self.arena_allocator.allocator().create(PlatformWindow);
        pw_instance_ptr.* = try PlatformWindow.init(self.arena_allocator, self, window_title, width, height);
        self.platform_window = pw_instance_ptr;
    }

    /// Tries to get platform window instance.
    /// In case that platform window instance if null returns error.
    pub fn getPlatformWindow(self: *Window) !*PlatformWindow {
        if (self.platform_window) |ptr| {
            return ptr;
        } else {
            return error.NullPointer;
        }
    }

    /// Shows platform window instance, in case that platform window instance is null returns error
    pub fn show(self: *Window) !void {
        const pw_instance = try self.getPlatformWindow();
        try pw_instance.show();
    }

    /// Runs platform window instance, in case that platform window instance is null returns error
    pub fn run(self: *Window) !void {
        const pw_instance = try self.getPlatformWindow();
        try pw_instance.run();
    }
};

// Select platform at compile time
const impl = switch (builtin.os.tag) {
    .windows => @import("../platform/windows.zig"),
    .linux => @import("../platform/wayland.zig"),
    else => @compileError("Unsupported OS"),
};

pub const PlatformWindow = impl.PlatformWindow;
