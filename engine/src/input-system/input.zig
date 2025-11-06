const std = @import("std");

const KeyCode = @import("keycode/keycode.zig").KeyCode;
const MouseButton = @import("../event-system/models/mouse-button.zig").MouseButton;
const Vector2 = @import("../vectors/vector2.zig").Vector2;

pub const InputSystem = struct {
    arena_allocator: *std.heap.ArenaAllocator,

    pressed_keys: std.ArrayList(KeyCode), // TODO: Maybe use AutoHashMap instead for better performance
    down_since_last_frame: std.ArrayList(KeyCode),
    up_since_last_frame: std.ArrayList(KeyCode),

    window_focused: bool = true,
    mouse_position: Vector2,
    pressed_mouse_buttons: std.ArrayList(MouseButton),
    down_since_last_frame_mouse_buttons: std.ArrayList(MouseButton),
    up_since_last_frame_mouse_buttons: std.ArrayList(MouseButton),

    pub fn create(arena_allocator: *std.heap.ArenaAllocator) !InputSystem {
        return InputSystem{
            .arena_allocator = arena_allocator,

            .pressed_keys = std.ArrayList(KeyCode){},
            .down_since_last_frame = std.ArrayList(KeyCode){},
            .up_since_last_frame = std.ArrayList(KeyCode){},

            .window_focused = true,
            .mouse_position = Vector2.zero(),
            .pressed_mouse_buttons = std.ArrayList(MouseButton){},
            .down_since_last_frame_mouse_buttons = std.ArrayList(MouseButton){},
            .up_since_last_frame_mouse_buttons = std.ArrayList(MouseButton){},
        };
    }

    /// Prepares the input system for a new frame by clearing the sets of keys or buttons
    /// that have been pressed or released since the last frame. This should be called
    /// at the beginning of each frame to ensure input events are tracked correctly.
    pub fn beginFrame(self: *InputSystem) !void {
        self.down_since_last_frame.clearRetainingCapacity();
        self.up_since_last_frame.clearRetainingCapacity();

        self.down_since_last_frame_mouse_buttons.clearRetainingCapacity();
        self.up_since_last_frame_mouse_buttons.clearRetainingCapacity();
    }

    pub fn registerKey(self: *InputSystem, key: KeyCode) void {
        for (self.pressed_keys.items) |existing| {
            if (existing == key) return;
        }

        self.pressed_keys.append(self.arena_allocator.allocator(), key) catch |e| {
            std.log.err("Failed to add key to pressed keys: {}", .{e});
        };

        self.down_since_last_frame.append(self.arena_allocator.allocator(), key) catch |e| {
            std.log.err("Failed to add key to down since last frame: {}", .{e});
        };
    }

    pub fn unregisterKey(self: *InputSystem, key: KeyCode) void {
        var i: usize = 0;

        while (i < self.pressed_keys.items.len) : (i += 1) {
            if (self.pressed_keys.items[i] == key) {
                _ = self.pressed_keys.swapRemove(i);
                self.up_since_last_frame.append(self.arena_allocator.allocator(), key) catch |e| {
                    std.log.err("Failed to add key to up since last frame: {}", .{e});
                };
                break;
            }
        }
    }

    pub fn registerMouseButton(self: *InputSystem, button: MouseButton) void {
        for (self.pressed_mouse_buttons.items) |existing| {
            if (existing == button) return;
        }

        self.pressed_mouse_buttons.append(self.arena_allocator.allocator(), button) catch |e| {
            std.log.err("Failed to add mouse button to pressed mouse buttons: {}", .{e});
        };

        self.down_since_last_frame_mouse_buttons.append(self.arena_allocator.allocator(), button) catch |e| {
            std.log.err("Failed to add mouse button to down since last frame: {}", .{e});
        };
    }

    pub fn unregisterMouseButton(self: *InputSystem, button: MouseButton) void {
        var i: usize = 0;

        while (i < self.pressed_mouse_buttons.items.len) : (i += 1) {
            if (self.pressed_mouse_buttons.items[i] == button) {
                _ = self.pressed_mouse_buttons.swapRemove(i);
                self.up_since_last_frame_mouse_buttons.append(self.arena_allocator.allocator(), button) catch |e| {
                    std.log.err("Failed to add mouse button to up since last frame: {}", .{e});
                };
                break;
            }
        }
    }

    pub fn isPressed(self: *InputSystem, key: KeyCode) bool {
        for (self.pressed_keys.items) |current| {
            if (current == key) return true;
        }

        return false;
    }

    pub fn isComboPressed(self: *InputSystem, keys: []const KeyCode) bool {
        for (keys) |current| {
            if (!self.isPressed(current)) return false;
        }

        return true;
    }

    pub fn getKeyDown(self: *InputSystem, key: KeyCode) bool {
        for (self.down_since_last_frame.items) |current| {
            if (current == key) return true;
        }

        return false;
    }

    pub fn getComboKeyDown(self: *InputSystem, keys: []const KeyCode) bool {
        for (keys) |current| {
            if (!self.getKeyDown(current)) return false;
        }

        return true;
    }

    pub fn getKeyUp(self: *InputSystem, key: KeyCode) bool {
        for (self.up_since_last_frame.items) |current| {
            if (current == key) return true;
        }

        return false;
    }

    pub fn getComboKeyUp(self: *InputSystem, keys: []const KeyCode) bool {
        for (keys) |current| {
            if (!self.getKeyUp(current)) return false;
        }

        return true;
    }

    pub fn isMouseButtonPressed(self: *InputSystem, button: MouseButton) bool {
        for (self.pressed_mouse_buttons.items) |current| {
            if (current == button) return true;
        }

        return false;
    }

    pub fn isMouseComboPressed(self: *InputSystem, buttons: []const MouseButton) bool {
        for (buttons) |current| {
            if (!self.isMouseButtonPressed(current)) return false;
        }

        return true;
    }

    pub fn getMouseButtonDown(self: *InputSystem, button: MouseButton) bool {
        for (self.down_since_last_frame_mouse_buttons.items) |current| {
            if (current == button) return true;
        }

        return false;
    }

    pub fn getMouseComboButtonDown(self: *InputSystem, buttons: []const MouseButton) bool {
        for (buttons) |current| {
            if (!self.getMouseButtonDown(current)) return false;
        }

        return true;
    }

    pub fn getMouseButtonUp(self: *InputSystem, button: MouseButton) bool {
        for (self.up_since_last_frame_mouse_buttons.items) |current| {
            if (current == button) return true;
        }

        return false;
    }

    pub fn getMouseComboButtonUp(self: *InputSystem, buttons: []const MouseButton) bool {
        for (buttons) |current| {
            if (!self.getMouseButtonUp(current)) return false;
        }

        return true;
    }
};
