const std = @import("std");

const arena_allocator_util = @import("../utils/arena_allocator_util.zig");
const allocNewArena = arena_allocator_util.allocateNewArenaWithC;
const freeArena = arena_allocator_util.freeArenaWithC;

const c_allocator_util = @import("../utils/c_allocator_util.zig");
const cAlloc = c_allocator_util.cAlloc;
const cFree = c_allocator_util.cFree;

const Scene = @import("./scene.zig").Scene;
const Vector3 = @import("../vectors/vector3.zig").Vector3;
const GameObject = @import("./game_object.zig").GameObject;
const SceneOptions = @import("./scene_options.zig").SceneOptions;
const Transform = @import("../components/transform.zig").Transform;

const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;

/// - Allocation: Managed (cAlloc)
/// - De-allocation: Managed (cFree)
pub const SpatialHash = struct {
    arena: *std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,

    scene: *Scene,

    cell_size: f32,
    grid_width: usize,
    grid_height: usize,

    cells: []std.ArrayList(*GameObject),
    cached_indexes: AutoHashMap(usize, void), // Holds indexes of cells that contain game objects

    pub fn create(scene: *Scene, world_width: f32, world_height: f32, cell_size: f32) !*SpatialHash {
        const arena = try allocNewArena();
        const allocator = arena.allocator();

        // Calculate grid dimensions
        const grid_width: usize = @intFromFloat(world_width / cell_size);
        const grid_height: usize = @intFromFloat(world_height / cell_size);

        var cells = try allocator.alloc(std.ArrayList(*GameObject), grid_height * grid_width);
        for (0..grid_height * grid_width) |i| {
            cells[i] = try std.ArrayList(*GameObject).initCapacity(allocator, 16);
        }

        // Initialize cached indexes hash map
        var cached_indexes = AutoHashMap(usize, void).init(allocator);
        try cached_indexes.ensureTotalCapacity(1024);

        // Allocate new instance of SpatialHash
        const instance: *SpatialHash = try cAlloc(SpatialHash);
        instance.* = SpatialHash{
            .arena = arena,
            .allocator = allocator,
            .scene = scene,
            .cell_size = cell_size,
            .grid_width = grid_width,
            .grid_height = grid_height,
            .cells = cells,
            .cached_indexes = cached_indexes,
        };

        return instance;
    }

    pub fn deinit(self: *SpatialHash) void {
        for (&self.thread_pool) |*worker| {
            worker.stop(); // stops and joins
        }

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

    pub fn registerGameObjects(self: *SpatialHash) !void {
        self.scene.active_game_objects_mutex.lock();
        defer self.scene.active_game_objects_mutex.unlock();

        self.cached_indexes.clearRetainingCapacity();

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

                    try self.cached_indexes.put(index, {});
                }
            }
        }

        //std.debug.print("\n", .{});
        //std.debug.print("\nCached keys amount: {}", .{self.cached_indexes.count()});
        //var a = self.cached_indexes.iterator();
        //while (a.next()) |entry| {
        //    std.debug.print("\nCached key: {}", .{entry.key_ptr.*});
        //}
        //std.debug.print("\n", .{});
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
