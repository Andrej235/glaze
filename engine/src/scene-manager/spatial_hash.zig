const std = @import("std");

const arena_allocator_util = @import("../utils/arena_allocator_util.zig");
const allocNewArena = arena_allocator_util.allocateNewArenaWithC;
const freeArena = arena_allocator_util.freeArenaWithC;

const c_allocator_util = @import("../utils/c_allocator_util.zig");
const cAlloc = c_allocator_util.cAlloc;
const cFree = c_allocator_util.cFree;

const Vector3 = @import("../vectors/vector3.zig").Vector3;
const GameObject = @import("./game_object.zig").GameObject;
const Transform = @import("../components/transform.zig").Transform;

const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const HashMap = std.AutoHashMap;

const CellKey = struct { x: i32, y: i32 };

pub const SpatialHash = struct {
    const Self = @This();

    const cell_size: f32 = 50;

    arena: *ArenaAllocator,
    buckets: HashMap(CellKey, ArrayList(*GameObject)),

    pub fn create() !*Self {
        const arena = try allocNewArena();

        const instance: *Self = try cAlloc(Self);
        instance.* = Self{
            .arena = arena,
            .buckets = HashMap(CellKey, ArrayList(*GameObject)).init(arena.allocator()),
        };

        return instance;
    }

    pub fn deinit(self: *Self) void {
        const allocator = self.arena.allocator();

        var it = self.buckets.valueIterator();
        while (it.next()) |list| list.deinit(allocator);

        self.buckets.deinit();
        freeArena(self.arena);
        cFree(self);
    }

    pub fn add(self: *Self, game_object: *GameObject) !void {
        const game_object_transform: *Transform = game_object.getComponent(Transform) orelse return;
        const cell_key: CellKey = toCellKey(game_object_transform.position);

        const allocator = self.arena.allocator();

        var entry = try self.buckets.getOrPut(cell_key);
        if (!entry.found_existing) {
            entry.value_ptr.* = try ArrayList(*GameObject).initCapacity(allocator, 1);
        }

        try entry.value_ptr.append(allocator, game_object);
    }

    fn toCellKey(position: Vector3) CellKey {
        return .{
            .x = @intFromFloat(std.math.floor(position.x / cell_size)),
            .y = @intFromFloat(std.math.floor(position.y / cell_size)),
        };
    }
};
