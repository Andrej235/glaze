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

pub const SpatialHash = struct {
    arena: *std.heap.ArenaAllocator,
    cell_size: f32,
    grid_width: usize,
    grid_height: usize,
    cells: [][]std.ArrayList(*GameObject),

    pub fn create(world_width: f32, world_height: f32, cell_size: f32) !*SpatialHash {
        // Create new allocator for spatial hash
        const arena = try allocNewArena();
        errdefer freeArena(arena);

        const allocator = arena.allocator();

        // Preallocate some capacity
        const grid_width: usize = @intFromFloat(world_width / cell_size);
        const grid_height: usize = @intFromFloat(world_height / cell_size);

        var cells = try allocator.alloc([]std.ArrayList(*GameObject), grid_height);
        for (0..grid_height) |y| {
            cells[y] = try allocator.alloc(std.ArrayList(*GameObject), grid_width);
            for (0..grid_width) |x| {
                cells[y][x] = std.ArrayList(*GameObject){};
                try cells[y][x].ensureTotalCapacity(allocator, 16);
            }
        }

        const instance: *SpatialHash = try cAlloc(SpatialHash);
        instance.* = SpatialHash{
            .arena = arena,
            .cell_size = cell_size,
            .grid_width = grid_width,
            .grid_height = grid_height,
            .cells = cells,
        };

        return instance;
    }

    pub fn deinit(self: *SpatialHash) void {
        const allocator = self.arena.allocator();

        for (0..self.grid_height) |y| {
            for (0..self.grid_width) |x| {
                self.cells[y][x].deinit();
            }
            allocator.free(self.cells[y]);
        }
        allocator.free(self.cells);

        freeArena(self.arena);
        cFree(self);
    }

    pub fn clear(self: *SpatialHash) void {
        for (0..self.grid_height) |y| {
            for (0..self.grid_width) |x| {
                self.cells[y][x].clearRetainingCapacity();
            }
        }
    }

    pub fn registerObject(self: *SpatialHash, obj: *GameObject) !void {
        // Skip object if it doesn't have a transform
        const transform: *Transform = obj.getComponent(Transform) orelse return;

        const range = self.getCellRange(transform);

        const allocator = self.arena.allocator();

        for (range.y0..range.y1 + 1) |y| {
            for (range.x0..range.x1 + 1) |x| {
                try self.cells[y][x].append(allocator, obj);
            }
        }
    }

    fn getCellRange(self: *SpatialHash, transform: *Transform) struct { x0: usize, x1: usize, y0: usize, y1: usize } {
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
        const x0: usize = @intFromFloat(@max(raw_x0, 0));
        const x1: usize = @intFromFloat(@max(raw_x1, 0));
        const y0: usize = @intFromFloat(@max(raw_y0, 0));
        const y1: usize = @intFromFloat(@max(raw_y1, 0));

        return .{
            .x0 = @min(x0, self.grid_width - 1),
            .x1 = @min(x1, self.grid_width - 1),
            .y0 = @min(y0, self.grid_height - 1),
            .y1 = @min(y1, self.grid_height - 1),
        };
    }
};
