const std = @import("std");

pub fn SceneInterface(comptime TScene: type) type {
    return struct {
        name: []const u8,
        create: *const fn (arena: *std.heap.ArenaAllocator) TScene,
    };
}
