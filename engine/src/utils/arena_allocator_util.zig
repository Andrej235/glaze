const std = @import("std");

const c_allocator_util = @import("./c_allocator_util.zig");
const cAlloc = c_allocator_util.cAlloc;
const cFree = c_allocator_util.cFree;

pub fn allocateNewArena() !*std.heap.ArenaAllocator {
    const arena: *std.heap.ArenaAllocator = try std.heap.page_allocator.create(std.heap.ArenaAllocator);
    arena.* = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    return arena;
}

pub fn allocateNewArenaWithC() !*std.heap.ArenaAllocator {
    const arena: *std.heap.ArenaAllocator = try cAlloc(std.heap.ArenaAllocator);
    arena.* = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    return arena;
}

pub fn freeArenaWithPageAllocator(arena: *std.heap.ArenaAllocator) void {
    arena.deinit();
    std.heap.page_allocator.destroy(arena);
}

pub fn freeArenaWithC(arena: *std.heap.ArenaAllocator) void {
    arena.deinit();
    cFree(arena);
}
