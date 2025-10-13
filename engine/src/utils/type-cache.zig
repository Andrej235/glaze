const std = @import("std");

pub fn TypeCache(comptime allocatorType: type) type {
    return struct {
        const Self = @This();
        allocator: *allocatorType,
        map: std.AutoHashMap(u64, usize),

        pub fn init(allocator: *allocatorType) Self {
            return .{
                .allocator = allocator,
                .map = std.AutoHashMap(u64, usize).init(allocator.allocator()),
            };
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        fn typeHash(comptime T: type) u64 {
            return std.hash.Wyhash.hash(0, @typeName(T));
        }

        pub fn getOrCreate(self: *Self, comptime T: type, createFn: fn (*allocatorType) anyerror!*T) !*T {
            const hash = typeHash(T);

            if (self.map.get(hash)) |ptr_usize| {
                return @ptrFromInt(ptr_usize);
            }

            const instance = try createFn(self.allocator);
            self.map.put(hash, @intFromPtr(instance)) catch unreachable;
            return instance;
        }

        pub fn get(self: *Self, comptime T: type) ?*T {
            const hash = typeHash(T);
            return if (self.map.get(hash)) |ptr_usize|
                @ptrFromInt(ptr_usize)
            else
                null;
        }
    };
}
