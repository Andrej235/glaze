const std = @import("std");

pub fn cAlloc(comptime T: type) !*T {
    return try std.heap.c_allocator.create(T);
}

pub fn cFree(ptr: anytype) void {
    std.heap.c_allocator.destroy(ptr);
}

pub fn cRawAlloc(size: usize, alignment: std.mem.Alignment) ?[*]u8 {
    return std.heap.c_allocator.rawAlloc(size, alignment, @returnAddress());
}

pub fn cRawFree(ptr: [*]u8, size: usize, alignment: std.mem.Alignment) void {
    std.heap.c_allocator.rawFree(ptr[0..size], alignment, @returnAddress());
}
