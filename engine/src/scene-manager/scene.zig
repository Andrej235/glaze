const std = @import("std");

const ArrayList = std.ArrayList;

const App = @import("../app.zig").App;
const GameObject = @import("game_object.zig").GameObject;

pub const Scene = struct {
    arena_allocator: *std.heap.ArenaAllocator,
    gp_allocator: std.heap.GeneralPurposeAllocator(.{}),

    app: *App,
    name: []const u8,

    next_id: usize,
    free_ids: ArrayList(usize),
    game_objects: ArrayList(*GameObject),

    mutex: std.Thread.Mutex,

    pub fn create(name: []const u8, app: *App, arena_allocator: *std.heap.ArenaAllocator) !Scene {
        return Scene{
            .arena_allocator = arena_allocator,
            .gp_allocator = std.heap.GeneralPurposeAllocator(.{}){},
            .name = name,
            .app = app,
            .next_id = 0,
            .free_ids = ArrayList(usize){},
            .game_objects = ArrayList(*GameObject){},
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn destroy(self: *Scene) void {
        for (self.game_objects.items) |item| {
            item.destroy() catch {
                std.log.err("Failed to destroy game object", .{});
            };

            item.arena_allocator.deinit();

            std.heap.page_allocator.destroy(item.arena_allocator);
        }

        const allocator = self.arena_allocator.allocator();

        self.game_objects.deinit(allocator);
        self.free_ids.deinit(allocator);
        _ = self.gp_allocator.deinit();
        self.arena_allocator.deinit();
        std.heap.page_allocator.destroy(self.arena_allocator);
    }

    /// Tries to add entity
    ///
    /// # Returns
    /// - `*GameObject`: The created game object
    ///
    /// # Errors
    /// - `GameObjectArenaAllocatorCreationFailed`: If game object arena allocator could not be created
    /// - `GameObjectAllocationFailed`: If game object could not be allocated
    /// - `GameObjectCreationFailed`: If game object could not be created
    /// - `FalseFreeId`: Tried to get free id but there are none
    /// - `GameObjectAppendFailed`: If game object could not be appended
    pub fn addEntity(self: *Scene) SceneError!*GameObject {
        const allocator = self.arena_allocator.allocator();

        self.mutex.lock();
        defer self.mutex.unlock();

        // Create new instance of game object
        const arena: *std.heap.ArenaAllocator = try createGameObjectArenaAllocator();
        const game_object = allocator.create(GameObject) catch return SceneError.GameObjectAllocationFailed;
        game_object.* = GameObject.create(self.app, arena);

        // Assign unique id
        const id = self.getFreeId() catch |e| {
            // Failed to get free id and we need to clean up allocated memory
            try self.freeGameObject(game_object);

            return e;
        };

        game_object.setId(id);

        // Try to append game object
        self.game_objects.append(allocator, game_object) catch {
            const game_object_id = game_object.unique_id;
            try self.freeGameObject(game_object);
            try self.setFreeId(game_object_id);

            return SceneError.GameObjectAppendFailed;
        };

        return game_object;
    }

    /// Tries to remove entity
    ///
    /// # Parameters
    /// - `id`: The id of the entity
    ///
    /// # Errors
    /// - `GameObjectDestroyFailed`: If game object could not be destroyed
    /// - `FreeIdAppendFailed`: If free id could not be appended
    pub fn removeEntity(self: *Scene, id: usize) SceneError!void {
        const allocator = self.arena_allocator.allocator();

        self.mutex.lock();
        defer self.mutex.unlock();

        // Find game object
        var game_object: ?*GameObject = null;
        var index_of_game_object: usize = 0;

        for (self.game_objects.items) |item| {
            if (item.unique_id == id) {
                game_object = item;
                break;
            }

            index_of_game_object += 1;
        }

        // Free game object if found
        if (game_object) |item| {

            // Remove game object from list
            const item_id = item.unique_id; // We save it here so we know which id to reuse

            // Free up game object memory
            try self.freeGameObject(item);

            _ = self.game_objects.swapRemove(index_of_game_object);

            // Return id into list to be reused
            self.free_ids.append(allocator, item_id) catch return SceneError.FreeIdAppendFailed;
        }
    }

    // --------------------------- HELPER FUNCTIONS --------------------------- //
    fn getFreeId(self: *Scene) SceneError!usize {
        if (self.free_ids.items.len > 0) {
            return self.free_ids.pop() orelse return SceneError.FalseFreeId;
        } else {
            const id = self.next_id;
            self.next_id += 1;
            return id;
        }
    }

    fn setFreeId(self: *Scene, id: usize) SceneError!void {
        self.free_ids.append(self.arena_allocator.allocator(), id) catch return SceneError.FreeIdAppendFailed;
    }

    fn createGameObjectArenaAllocator() SceneError!*std.heap.ArenaAllocator {
        const arena: *std.heap.ArenaAllocator = std.heap.page_allocator.create(std.heap.ArenaAllocator) catch return SceneError.GameObjectArenaAllocatorCreationFailed;
        arena.* = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        return arena;
    }

    fn freeGameObject(self: *Scene, game_object: *GameObject) SceneError!void {
        game_object.destroy() catch return SceneError.GameObjectDestroyFailed;
        game_object.arena_allocator.deinit();
        std.heap.page_allocator.destroy(game_object.arena_allocator);
        self.arena_allocator.allocator().destroy(game_object);
    }
};

pub const SceneError = error{
    FalseFreeId,
    FreeIdAppendFailed,
    GameObjectAppendFailed,
    GameObjectArenaAllocatorCreationFailed,
    GameObjectAllocationFailed,
    GameObjectCreationFailed,
    GameObjectDestroyFailed,
};
