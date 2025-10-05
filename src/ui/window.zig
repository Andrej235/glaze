// ****************************************************************
// IMPORTS
// ****************************************************************
const std = @import("std");
const builtin = @import("builtin");

const event_manager = @import("../event-system/event_manager.zig");

const WindowEvents = @import("../event-system/events/window_events.zig").WindowEvents;

// ****************************************************************
// TYPES
// ****************************************************************

// ****************************************************************
// MAIN
// ****************************************************************
pub const Window = struct {
    allocator_ptr: *std.heap.ArenaAllocator,

    platform_window_ptr: ?*PlatformWindow = null,

    window_events_ptr: *WindowEvents,

    pub fn init(allocator_ptr: *std.heap.ArenaAllocator) !Window {
        const window_events_ptr: *WindowEvents = (try event_manager.getEventManager()).getWindowEvents();
        return Window{ .allocator_ptr = allocator_ptr, .window_events_ptr = window_events_ptr };
    }

    /// Initializes platform window instance because we don't have access to window instance in ini() function
    pub fn initPlatformWindow(self: *Window, window_title: []const u8, width: i16, height: i16) !void {
        const pw_instance_ptr = try self.allocator_ptr.allocator().create(PlatformWindow);
        pw_instance_ptr.* = try PlatformWindow.init(self.allocator_ptr, self, window_title, width, height);
        self.platform_window_ptr = pw_instance_ptr;
    }

    /// Tries to get platform window instance.
    /// In case that platform window instance if null returns error.
    pub fn getPlatformWindow(self: *Window) !*PlatformWindow {
        if (self.platform_window_ptr) |ptr| {
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
        pw_instance.run();
    }
};

// Select platform at compile time
const impl = switch (builtin.os.tag) {
    .windows => @import("../platform/windows.zig"),
    .linux => @import("../platform/wayland.zig"),
    else => @compileError("Unsupported OS"),
};

pub const PlatformWindow = impl.PlatformWindow;
