const std = @import("std");

pub fn RefCounter(comptime T: type) type {
    return struct {
        const Self = @This();

        ptr: *Inner,

        const Inner = struct {
            count: usize,
            value: T,
        };

        pub fn create(value: T) !Self {
            const inner = try std.heap.c_allocator.create(Inner);

            inner.* = .{
                .count = 1,
                .value = value,
            };

            return Self{
                .ptr = inner,
            };
        }

        pub fn clone(self: *Self) Self {
            self.ptr.count += 1;

            return Self{
                .ptr = self.ptr,
            };
        }

        pub fn get(self: *Self) *T {
            return &self.ptr.value;
        }

        pub fn release(self: *Self) void {
            if (self.ptr.count == 0) return;

            self.ptr.count -= 1;

            if (self.ptr.count == 0) {
                std.heap.c_allocator.destroy(self.ptr);
            }
        }
    };
}
