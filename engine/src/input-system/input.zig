const std = @import("std");

const KeyCode = @import("keycode/keycode.zig").KeyCode;

pub const InputSystem = struct {
    arena_allocator: *std.heap.ArenaAllocator,
    pressed_keys: std.ArrayList(KeyCode), // TODO: Maybe use AutoHashMap instead for better performance
    down_since_last_frame: std.ArrayList(KeyCode),
    up_since_last_frame: std.ArrayList(KeyCode),

    pub fn create(arena_allocator: *std.heap.ArenaAllocator) !InputSystem {
        return InputSystem{
            .arena_allocator = arena_allocator,
            .pressed_keys = std.ArrayList(KeyCode){},
            .down_since_last_frame = std.ArrayList(KeyCode){},
            .up_since_last_frame = std.ArrayList(KeyCode){},
        };
    }

    /// Doesn't have any functionality yet.
    /// For now it just prints the pressed keys
    pub fn beginFrame(self: *InputSystem) !void {
        self.down_since_last_frame.clearRetainingCapacity();
        self.up_since_last_frame.clearRetainingCapacity();

        if (self.pressed_keys.items.len > 0) {
            // std.debug.print("Keys: {any}\n", .{self.pressed_keys.items});
        }
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
};
