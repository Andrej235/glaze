const std = @import("std");

const ArrayList = std.ArrayList;

const c_allocator_util = @import("../utils/c_allocator_util.zig");
const cAlloc = c_allocator_util.cAlloc;
const cFree = c_allocator_util.cFree;

const App = @import("../app.zig").App;
const GameObject = @import("game_object.zig").GameObject;

pub const Scene = struct {
    const minimum_inactive_game_object_count = 10;

    arena_allocator: *std.heap.ArenaAllocator,
    gp_allocator: std.heap.GeneralPurposeAllocator(.{}),

    app: *App,
    name: []const u8,

    next_id: usize,
    free_ids: ArrayList(usize),

    active_game_objects: ArrayList(*GameObject),
    inactive_game_objects: ArrayList(*GameObject), // Holds game objects that will be deleted on next thread execution

    active_game_objects_mutex: std.Thread.Mutex,
    inactive_game_objects_mutex: std.Thread.Mutex,
    is_scene_active: bool,

    cleanup_thread: ?std.Thread,
    cleanup_thread_condition: std.Thread.Condition,
    exit_cleanup_thread_flag: std.atomic.Value(bool),

    pub fn create(name: []const u8, app: *App, arena_allocator: *std.heap.ArenaAllocator) !Scene {
        return Scene{
            .arena_allocator = arena_allocator,
            .gp_allocator = std.heap.GeneralPurposeAllocator(.{}){},
            .name = name,
            .app = app,
            .next_id = 0,
            .free_ids = ArrayList(usize){},
            .active_game_objects = ArrayList(*GameObject){},
            .inactive_game_objects = ArrayList(*GameObject){},
            .active_game_objects_mutex = std.Thread.Mutex{},
            .inactive_game_objects_mutex = std.Thread.Mutex{},
            .is_scene_active = false,
            .cleanup_thread = null,
            .cleanup_thread_condition = std.Thread.Condition{},
            .exit_cleanup_thread_flag = std.atomic.Value(bool).init(false),
        };
    }

    pub fn destroy(self: *Scene) void {
        for (self.active_game_objects.items) |item| {
            item.destroy() catch {
                std.log.err("Failed to destroy game object", .{});
            };

            cFree(item);
        }

        const allocator = self.arena_allocator.allocator();

        self.active_game_objects.deinit(allocator);
        self.free_ids.deinit(allocator);
        _ = self.gp_allocator.deinit();
        self.arena_allocator.deinit();
        std.heap.page_allocator.destroy(self.arena_allocator);
    }

    pub fn load(self: *Scene) !void {
        // Skip load if scene is already active
        if (self.is_scene_active) return;

        // Start cleanup thread
        self.cleanup_thread = std.Thread.spawn(.{}, cleanUpThread, .{self}) catch return SceneError.CleanupThreadCreationFailed;
        self.exit_cleanup_thread_flag.store(false, .release);

        self.is_scene_active = true;
    }

    pub fn unload(self: *Scene) !void {
        // If thread exists exit it
        if (self.cleanup_thread) |thread| {
            self.exit_cleanup_thread_flag.store(true, .release);
            self.cleanup_thread_condition.signal();
            thread.join();
        }

        self.is_scene_active = false;
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
    pub fn addGameObject(self: *Scene) SceneError!*GameObject {
        const allocator = self.arena_allocator.allocator();

        self.active_game_objects_mutex.lock();
        defer self.active_game_objects_mutex.unlock();

        // Create new instance of game object
        const game_object = cAlloc(GameObject) catch return SceneError.GameObjectAllocationFailed;
        game_object.* = GameObject.create(self.app);

        // Assign unique id
        const id = self.getFreeId() catch |e| {
            // Failed to get free id and we need to clean up allocated memory
            try freeGameObject(game_object);

            return e;
        };

        game_object.setId(id);

        // Try to append game object
        self.active_game_objects.append(allocator, game_object) catch {
            const game_object_id = game_object.unique_id;
            try freeGameObject(game_object);
            try self.setFreeId(game_object_id);

            return SceneError.GameObjectAppendFailed;
        };

        return game_object;
    }

    //#region Remove functions
    pub fn removeGameObject(_: *Scene, _: *GameObject) SceneError!void {}

    /// Tries to remove game object by id
    ///
    /// ### Arguments
    /// - `id`: Game object id
    ///
    /// ### Errors
    /// - `GameObjectDoesNotExist`: Game object does not exist
    /// - `FailedToQueueGameObjectForDeletion`: Failed to queue game object for deletion
    pub fn removeGameObjectById(self: *Scene, id: usize) SceneError!void {
        const game_object = self.popGameObjectById(id) orelse return SceneError.GameObjectDoesNotExist;
        try self.queueGameObjectForDeletion(game_object);
    }

    pub fn removeGameObjectByName(_: *Scene, _: []const u8) SceneError!void {}
    pub fn removeGameObjectByTag(_: *Scene, _: []const u8) SceneError!void {}
    //#endregion

    //#region Get functions
    pub fn getGameObjectByName(_: *Scene, _: []const u8) ?*GameObject {}
    pub fn getGameObjectByTag(_: *Scene, _: []const u8) ?*GameObject {}

    pub fn getActiveGameObjects(self: *Scene) *ArrayList(*GameObject) {
        return &self.active_game_objects;
    }
    //#endregion

    // --------------------------- HELPER FUNCTIONS --------------------------- //
    //#region Helper functions
    fn cleanUpThread(self: *Scene) void {
        while (true) {
            // Check if thread should exit
            if (self.exit_cleanup_thread_flag.load(.acquire) == true) break;

            // Wait until there are 10 inactive game objects
            while (self.inactive_game_objects.items.len < minimum_inactive_game_object_count) {
                self.cleanup_thread_condition.wait(&self.inactive_game_objects_mutex);
            }

            // Aquire lock to temporarily allow access to inactive game objects
            self.inactive_game_objects_mutex.lock();
            defer self.inactive_game_objects_mutex.unlock();

            for (0..self.inactive_game_objects.items.len) |_| {
                const game_object = self.inactive_game_objects.pop();

                if (game_object) |obj| {
                    freeGameObject(obj) catch std.log.err("Failed to free game object, name: {s}", .{obj.name.?.getText()});
                }
            }
        }
    }

    /// Aquires lock on active game objects until it removes game object from list
    ///
    /// ### Arguments
    /// - `id`: Game object id
    ///
    /// ### Returns
    /// - `*GameObject`: The removed game object
    fn popGameObjectById(self: *Scene, id: usize) ?*GameObject {
        self.active_game_objects_mutex.lock();
        defer self.active_game_objects_mutex.unlock();

        for (self.active_game_objects.items, 0..) |item, index| {
            if (item.unique_id == id) {
                return self.active_game_objects.swapRemove(index);
            }
        }

        return null;
    }

    /// Aquires lock on inactive game objects until it appends game object to list
    ///
    /// ### Arguments
    /// - `game_object`: Game object to append
    ///
    /// ### Errors
    /// - `FailedToQueueGameObjectForDeletion`: Failed to queue game object for deletion
    fn queueGameObjectForDeletion(self: *Scene, game_object: *GameObject) SceneError!void {
        self.inactive_game_objects_mutex.lock();
        defer self.inactive_game_objects_mutex.unlock();

        self.inactive_game_objects.append(self.arena_allocator.allocator(), game_object) catch return SceneError.FailedToQueueGameObjectForDeletion;

        // Signal cleanup thread that new game object has queued
        self.cleanup_thread_condition.signal();
    }

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

    fn freeGameObject(game_object: *GameObject) SceneError!void {
        game_object.destroy() catch return SceneError.GameObjectDestroyFailed;
        cFree(game_object);
    }
    //#endregion
};

pub const SceneError = error{
    FalseFreeId,
    FreeIdAppendFailed,
    GameObjectDoesNotExist,
    FailedToQueueGameObjectForDeletion,
    GameObjectAppendFailed,
    GameObjectArenaAllocatorCreationFailed,
    GameObjectAllocationFailed,
    GameObjectCreationFailed,
    GameObjectDestroyFailed,
    CleanupThreadCreationFailed,
};
