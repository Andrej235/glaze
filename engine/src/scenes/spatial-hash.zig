const std = @import("std");

const arena_allocator_util = @import("../utils/arena_allocator_util.zig");
const allocNewArena = arena_allocator_util.allocateNewArenaWithC;
const freeArena = arena_allocator_util.freeArenaWithC;

const Caster = @import("../utils/caster.zig");

const c_allocator_util = @import("../utils/c_allocator_util.zig");
const cAlloc = c_allocator_util.cAlloc;
const cFree = c_allocator_util.cFree;

const Scene = @import("./scene.zig").Scene;
const Vector3 = @import("../vectors/vector3.zig").Vector3;
const GameObject = @import("../game-object/game-object.zig").GameObject;
const SceneOptions = @import("./scene-options.zig").SceneOptions;
const Transform = @import("../components/transform.zig").Transform;

const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;

/// - Allocation: Managed (cAlloc)
/// - De-allocation: Managed (cFree)
pub fn SpatialHash(comptime TBitMapItemType: type, comptime width: u16, comptime height: u16, comptime cell_size: u8) type {
    if (@typeInfo(TBitMapItemType).int.signedness != .unsigned)
        @compileError("TBitMapItemType must be an unsigned integer type");

    const grid_width = width / cell_size;
    const grid_height = height / cell_size;
    const cell_count: u32 = @as(u32, grid_width) * grid_height;

    const bit_item_size: u32 = comptime @bitSizeOf(TBitMapItemType);
    const bit_set_size = cell_count / bit_item_size;

    return struct {
        const Self = @This();

        arena: *std.heap.ArenaAllocator,
        allocator: std.mem.Allocator,

        scene: *Scene,

        cell_size: f32 = cell_size,
        grid_width: usize = grid_width,
        grid_height: usize = grid_height,
        cell_count: usize = cell_count,

        cells: *[cell_count]std.ArrayList(*GameObject),
        active_cells_bit_set: *[bit_set_size]u64,

        pub fn create(scene: *Scene) !*Self {
            const arena = try allocNewArena();
            const allocator = arena.allocator();

            var cells = try allocator.create([cell_count]std.ArrayList(*GameObject));
            for (0..cell_count) |i| {
                cells[i] = try std.ArrayList(*GameObject).initCapacity(allocator, 16);
            }

            var bit_set = try allocator.create([bit_set_size]u64);
            for (0..bit_set_size) |i| {
                bit_set[i] = 0;
            }

            // allocate instance
            const instance: *Self = try cAlloc(Self);
            instance.* = Self{
                .arena = arena,
                .allocator = allocator,
                .scene = scene,
                .cells = cells,
                .active_cells_bit_set = bit_set,
            };

            return instance;
        }

        pub fn createFns(self: *Self) !*SpatialHashFns {
            const fns = try cAlloc(SpatialHashFns);
            fns.* = SpatialHashFns{
                .instance = self,
                .registerGameObjects = registerGameObjects,
                .deinit = deinit,
            };

            return fns;
        }

        pub fn deinit(fns_instance: *anyopaque) !void {
            const self = try Caster.castFromNullableAnyopaque(Self, fns_instance);

            const allocator = self.arena.allocator();
            for (0..cell_count) |i| {
                self.cells[i].deinit(allocator);
            }
            allocator.free(self.cells);

            freeArena(self.arena);

            cFree(self);
        }

        pub fn registerGameObjects(fns_instance: *anyopaque) !void {
            @setRuntimeSafety(false);
            const self = try Caster.castFromNullableAnyopaque(Self, fns_instance);

            self.scene.active_game_objects_mutex.lock();
            defer self.scene.active_game_objects_mutex.unlock();

            const arr_ptr: [*]*GameObject = self.scene.active_game_objects.items.ptr;
            const arr_len: usize = self.scene.active_game_objects.items.len;

            // Add game objects to spatial hash
            var counter: usize = 0;
            while (counter < arr_len) : (counter += 1) {
                const obj: *GameObject = arr_ptr[counter];
                const transform: *Transform = obj.getComponent(Transform) orelse continue;

                const range = self.getCellRange(transform);

                for (range.y0..range.y1 + 1) |y| {
                    for (range.x0..range.x1 + 1) |x| {
                        const index = y * self.grid_width + x;

                        try self.cells[index].append(self.allocator, obj);

                        const bit_set_index = index / bit_item_size;
                        const bit_item_index = index % bit_item_size;
                        self.active_cells_bit_set[bit_set_index] |= @as(u64, 1) << @intCast(bit_item_index);
                    }
                }
            }
            @setRuntimeSafety(true);
        }

        fn getCellRange(self: *Self, transform: *Transform) struct { x0: usize, x1: usize, y0: usize, y1: usize } {
            const pos: Vector3 = transform.position;
            const scale: Vector3 = transform.scale;

            const half_w = scale.x * 0.5;
            const half_h = scale.y * 0.5;

            const min_x = pos.x - half_w;
            const max_x = pos.x + half_w;
            const min_y = pos.y - half_h;
            const max_y = pos.y + half_h;

            const raw_x0 = @floor(min_x / self.cell_size);
            const raw_x1 = @floor(max_x / self.cell_size);
            const raw_y0 = @floor(min_y / self.cell_size);
            const raw_y1 = @floor(max_y / self.cell_size);

            // Clamp and ensure no negative indices
            const x0: usize = @intFromFloat(@max(raw_x0 + @as(f32, @floatFromInt(self.grid_width / 2)), 0));
            const x1: usize = @intFromFloat(@max(raw_x1 + @as(f32, @floatFromInt(self.grid_width / 2)), 0));
            const y0: usize = @intFromFloat(@max(raw_y0 + @as(f32, @floatFromInt(self.grid_height / 2)), 0));
            const y1: usize = @intFromFloat(@max(raw_y1 + @as(f32, @floatFromInt(self.grid_height / 2)), 0));

            return .{
                .x0 = @min(x0, self.grid_width - 1),
                .x1 = @min(x1, self.grid_width - 1),
                .y0 = @min(y0, self.grid_height - 1),
                .y1 = @min(y1, self.grid_height - 1),
            };
        }
    };
}

pub const SpatialHashFns = struct {
    registerGameObjects: *const fn (self: *anyopaque) anyerror!void,
    deinit: *const fn (self: *anyopaque) anyerror!void,

    instance: *anyopaque,
};
