const std = @import("std");

const KeyCode = @import("../../event-system/models/key_code.zig").KeyCode;

pub const InputSystem = struct {
    arena_allocator: *std.heap.ArenaAllocator,
    pressed_keys: std.ArrayList(KeyCode), // TODO: Maybe use AutoHashMap instead for better performance

    pub fn create(arena_allocator: *std.heap.ArenaAllocator) !InputSystem {
        return InputSystem{
            .arena_allocator = arena_allocator,
            .pressed_keys = std.ArrayList(KeyCode){},
        };
    }

    /// Doesn't have any functionality yet.
    /// For now it just prints the pressed keys
    pub fn beginFrame(self: *InputSystem) !void {
        if (self.pressed_keys.items.len > 0) {
            std.debug.print("\nKeys: {any}", .{self.pressed_keys.items});
        }
    }

    pub fn registerKey(self: *InputSystem, key: KeyCode) void {
        for (self.pressed_keys.items) |existing| {
            if (existing == key) return;
        }

        self.pressed_keys.append(self.arena_allocator.allocator(), key) catch |e| {
            std.log.err("Failed to add key to pressed keys: {}", .{e});
        };
    }

    pub fn unregisterKey(self: *InputSystem, key: KeyCode) void {
        var i: usize = 0;

        while (i < self.pressed_keys.items.len) : (i += 1) {
            if (self.pressed_keys.items[i] == key) {
                _ = self.pressed_keys.orderedRemove(i);
                break;
            }
        }
    }

    pub fn isPressed(self: *InputSystem, key: KeyCode) bool {
        for (self.pressed_keys.items) |pressed| {
            if (pressed == key) return true;
        }

        return false;
    }

    pub fn isComboPressed(self: *InputSystem, keys: []const KeyCode) bool {
        for (keys) |k| {
            if (!self.isPressed(k)) return false;
        }

        return true;
    }
};
