const std = @import("std");

const arena_allocator_util = @import("../utils/arena_allocator_util.zig");
const allocNewArena = arena_allocator_util.allocateNewArenaWithC;
const freeArena = arena_allocator_util.freeArenaWithC;

const c_allocator_util = @import("../utils/c_allocator_util.zig");
const cAlloc = c_allocator_util.cAlloc;
const cFree = c_allocator_util.cFree;

const Vector3 = @import("../vectors/vector3.zig").Vector3;
const GameObject = @import("./game_object.zig").GameObject;
const SceneOptions = @import("./scene_options.zig").SceneOptions;
const Transform = @import("../components/transform.zig").Transform;

const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const HashMap = std.AutoHashMap;

const CellKey = struct { x: i32, y: i32 };

pub const SpatialHash = struct {
    const Self = @This();

    const cell_size: f32 = 50;

    arena: *ArenaAllocator,
    options: *SceneOptions,

    buckets: HashMap(CellKey, ArrayList(*GameObject)),

    pub fn create(options: *SceneOptions) !*Self {
        const arena = try allocNewArena();

        const instance: *Self = try cAlloc(Self);
        instance.* = Self{
            .arena = arena,
            .options = options,
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
        const transform: *Transform = game_object.getComponent(Transform) orelse return;
        const position = transform.position;
        const scale = transform.scale;

        // Compute the bounding box corners
        const half_w = scale.x * 0.5;
        const half_h = scale.y * 0.5;

        const min_x = position.x - half_w;
        const max_x = position.x + half_w;
        const min_y = position.y - half_h;
        const max_y = position.y + half_h;

        // Compute cell ranges that object overlaps
        const min_cell_x: i32 = @intFromFloat(std.math.floor(min_x / cell_size));
        const max_cell_x: i32 = @intFromFloat(std.math.floor(max_x / cell_size));
        const min_cell_y: i32 = @intFromFloat(std.math.floor(min_y / cell_size));
        const max_cell_y: i32 = @intFromFloat(std.math.floor(max_y / cell_size));

        const allocator = self.arena.allocator();

        // Insert object into all overlapping buckets
        var y = min_cell_y;
        while (y <= max_cell_y) : (y += 1) {
            var x = min_cell_x;
            while (x <= max_cell_x) : (x += 1) {
                const cell_key = CellKey{ .x = x, .y = y };
                var entry = try self.buckets.getOrPut(cell_key);
                if (!entry.found_existing) {
                    entry.value_ptr.* = try ArrayList(*GameObject).initCapacity(allocator, 1);
                }
                try entry.value_ptr.append(allocator, game_object);
            }
        }
    }
};
