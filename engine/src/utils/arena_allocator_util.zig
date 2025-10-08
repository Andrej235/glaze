const std = @import("std");

pub fn allocateNewArena() !*std.heap.ArenaAllocator {
    const arena: *std.heap.ArenaAllocator = try std.heap.page_allocator.create(std.heap.ArenaAllocator);
    arena.* = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    return arena;
}

pub fn freeArenaWithPageAllocator(arena: *std.heap.ArenaAllocator) void {
    arena.deinit();
    std.heap.page_allocator.destroy(arena);
}
