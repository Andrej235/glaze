const std = @import("std");

const ArrayList = std.ArrayList;

const GameObject = @import("game_object.zig").GameObject;

pub const RenderSystem = struct {
    arena_allocator: std.heap.ArenaAllocator,

    next_id: usize,
    free_ids: ArrayList(usize),
    game_objects: ArrayList(*GameObject),

    mutex: std.Thread.Mutex,

    pub fn init() !*RenderSystem {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        const rs_instance = try arena.allocator().create(RenderSystem);

        rs_instance.* = RenderSystem{
            .arena_allocator = arena,
            .next_id = 0,
            .free_ids = try ArrayList(usize).initCapacity(arena.allocator(), 10),
            .game_objects = try ArrayList(*GameObject).initCapacity(arena.allocator(), 10),
            .mutex = std.Thread.Mutex{},
        };
        
        return rs_instance;
    }

    pub fn addEntity(self: *RenderSystem, comptime TEntity: type, comptime TScript: type, entity: *TEntity, script: *TScript) !void {
        // Obtain thread lock to prevent race conditions
        self.mutex.lock();
        defer self.mutex.unlock();
        
        const game_object = try self.allocate(GameObject);
        game_object.* = try GameObject.init();
        try game_object.setEntity(TEntity, entity);
        try game_object.setScript(TScript, script);

        // Assign id
        var id: usize = undefined;

        if (self.free_ids.items.len > 0) {
            if (self.free_ids.pop()) |item| {
                id = item;
            } else {
                return error.FalseFreeId;
            }
        } else {
            id = self.next_id;
            self.next_id += 1;
        }

        game_object.setId(id);

        try self.game_objects.append(self.arena_allocator.allocator(), game_object);
    }

    pub fn removeEntity(self: *RenderSystem, id: usize) !void {
        // Obtain thread lock to prevent race conditions
        self.mutex.lock();
        defer self.mutex.unlock();

        // Find game object
        var game_object: ?*GameObject = null;
        var index_of_game_object: usize = 0;

        for (self.game_objects.items) |item| {
            if (item.id == id) {
                game_object = item;
                break;
            }

            index_of_game_object += 1;
        }

        // Free game object if found
        if (game_object) |item| {
            // Remove game object from list
            const item_id = item.id; // We save it here so we know which id to reuse
            _ = self.game_objects.swapRemove(index_of_game_object);

            // Free up game object memory
            try item.deinit();
            self.free(GameObject, item);

            // Return id into list to be reused
            try self.free_ids.append(self.arena_allocator.allocator(), item_id);
        }
    }

    /// Allocates memory for a new T object using render_system's allocator
    pub fn allocate(self: *RenderSystem, comptime T: type) !*T {
        return try self.arena_allocator.allocator().create(T);
    }

    /// Frees memory of T instance that was allocated by render_system's allocator
    pub fn free(self: *RenderSystem, comptime T: type, instance: *T) void {
        self.arena_allocator.allocator().destroy(instance);
    }
};

pub var render_system: ?*RenderSystem = null;

pub fn getRenderSystem() !*RenderSystem {
    if (render_system) |rs| return rs;

    const rs_instance = try RenderSystem.init();

    render_system = rs_instance;
    return rs_instance;
}