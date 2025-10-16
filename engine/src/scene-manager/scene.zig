const std = @import("std");

const ArrayList = std.ArrayList;

const caster = @import("../utils/caster.zig");

const c_allocator_util = @import("../utils/c_allocator_util.zig");
const cAlloc = c_allocator_util.cAlloc;
const cFree = c_allocator_util.cFree;

const App = @import("../app.zig").App;
const GameObject = @import("game_object.zig").GameObject;
const SpatialHash = @import("spatial_hash.zig").SpatialHash;
const SceneOptions = @import("scene_options.zig").SceneOptions;

pub const Scene = struct {
    const minimum_inactive_game_object_count = 10;

    arena_allocator: *std.heap.ArenaAllocator,

    app: *App,

    options: SceneOptions,
    name: []const u8,

    next_id: usize,
    free_ids: ArrayList(usize),

    active_game_objects: ArrayList(*GameObject),
    inactive_game_objects: ArrayList(*GameObject), // Holds game objects that will be deleted on next thread execution
    queued_game_objects: ArrayList(*GameObject), // Holds game objects that are created but not activated

    active_game_objects_mutex: std.Thread.Mutex,
    inactive_game_objects_mutex: std.Thread.Mutex,
    queued_game_objects_mutex: std.Thread.Mutex,
    is_scene_active: bool,

    spatial_hash: ?*SpatialHash = null,

    camera: ?*GameObject = null,

    pub fn create(options: SceneOptions, app: *App, arena_allocator: *std.heap.ArenaAllocator) !Scene {
        return Scene{
            .arena_allocator = arena_allocator,
            .name = options.name,
            .app = app,
            .options = options,
            .next_id = 0,
            .free_ids = ArrayList(usize){},
            .active_game_objects = ArrayList(*GameObject){},
            .inactive_game_objects = ArrayList(*GameObject){},
            .queued_game_objects = ArrayList(*GameObject){},
            .active_game_objects_mutex = std.Thread.Mutex{},
            .inactive_game_objects_mutex = std.Thread.Mutex{},
            .queued_game_objects_mutex = std.Thread.Mutex{},
            .is_scene_active = false,
        };
    }

    pub fn destroy(self: *Scene) void {
        const allocator = self.arena_allocator.allocator();

        // Free active objects
        for (self.active_game_objects.items) |item| {
            item.destroy() catch {};
            cFree(item);
        }
        self.active_game_objects.deinit(allocator);

        // Free inactive objects
        for (self.inactive_game_objects.items) |item| {
            item.destroy() catch {};
            cFree(item);
        }
        self.inactive_game_objects.deinit(allocator);

        // Free queued objects
        for (self.queued_game_objects.items) |item| {
            item.destroy() catch {};
            cFree(item);
        }
        self.queued_game_objects.deinit(allocator);

        self.free_ids.deinit(allocator);
        self.arena_allocator.deinit();
        std.heap.page_allocator.destroy(self.arena_allocator);
    }

    pub fn load(self: *Scene) !void {
        if (self.is_scene_active) return;

        _ = try self.app.renderer.on_request_frame_event.addHandler(onRequestFrameRender, self);

        self.is_scene_active = true;
    }

    pub fn unload(self: *Scene) !void {
        if (!self.is_scene_active) return;

        _ = try self.app.renderer.on_request_frame_event.removeHandler(onRequestFrameRender, self);

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

        self.queued_game_objects_mutex.lock();
        defer self.queued_game_objects_mutex.unlock();

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

        // Append new game object into queued game objects that will be activated
        self.queued_game_objects.append(allocator, game_object) catch {
            const game_object_id = game_object.unique_id;
            try freeGameObject(game_object);
            try self.setFreeId(game_object_id);

            return SceneError.GameObjectAppendFailed;
        };

        return game_object;
    }

    /// Activates all queued game objects
    pub fn activateGameObjects(self: *Scene) void {
        // Obtain needed locks to active queued game objects
        self.active_game_objects_mutex.lock();
        defer self.active_game_objects_mutex.unlock();

        self.queued_game_objects_mutex.lock();
        defer self.queued_game_objects_mutex.unlock();

        // Move queued game objects to active game objects
        self.active_game_objects.appendSlice(self.arena_allocator.allocator(), self.queued_game_objects.items) catch {
            std.log.err("Failed to append game objects to active game objects", .{});
        };

        self.queued_game_objects.clearRetainingCapacity();
    }

    /// Frees all inactive game objects
    pub fn clearInactiveGameObjects(self: *Scene) void {
        if (self.inactive_game_objects.items.len == 0) return;

        self.inactive_game_objects_mutex.lock();
        defer self.inactive_game_objects_mutex.unlock();

        for (self.inactive_game_objects.items) |item| {
            // Recycle id
            self.setFreeId(item.unique_id) catch |e| {
                std.log.err("Failed to set free id: {}", .{e});
            };

            // Free game object
            freeGameObject(item) catch |e| {
                std.log.err("Failed to free game object: {}", .{e});
            };
        }

        self.inactive_game_objects.clearRetainingCapacity();
    }

    pub fn makeCameraCurrent(self: *Scene, camera: *GameObject) void {
        self.camera = camera;
    }

    //#region Remove functions
    /// Tries to remove game object
    ///
    /// ### Arguments
    /// - `game_object`: Game object to remove
    ///
    /// ### Errors
    /// - `FailedToQueueGameObjectForDeletion`: Failed to queue game object for deletion
    pub fn removeGameObject(self: *Scene, game_object: *GameObject) SceneError!void {
        try self.queueGameObjectForDeletion(game_object);
    }

    /// Tries to remove game object by id
    ///
    /// ### Arguments
    /// - `id`: Game object id
    ///
    /// ### Errors
    /// - `GameObjectDoesNotExist`: Game object does not exist
    /// - `FailedToQueueGameObjectForDeletion`: Failed to queue game object for deletion
    pub fn removeGameObjectById(self: *Scene, id: usize) SceneError!void {
        const game_object = self.popGameObjectByOption(.{ .Id = id }) orelse return SceneError.GameObjectDoesNotExist;
        try self.queueGameObjectForDeletion(game_object);
    }

    /// Tries to remove game object by name
    ///
    /// ### Arguments
    /// - `name`: Game object name
    ///
    /// ### Errors
    /// - `GameObjectDoesNotExist`: Game object does not exist
    /// - `FailedToQueueGameObjectForDeletion`: Failed to queue game object for deletion
    pub fn removeGameObjectByName(self: *Scene, name: []const u8) SceneError!void {
        const game_object = self.popGameObjectByOption(.{ .Name = name }) orelse return SceneError.GameObjectDoesNotExist;
        try self.queueGameObjectForDeletion(game_object);
    }

    /// Tries to remove game object by tag
    ///
    /// ### Arguments
    /// - `tag`: Game object tag
    ///
    /// ### Errors
    /// - `GameObjectDoesNotExist`: Game object does not exist
    /// - `FailedToQueueGameObjectForDeletion`: Failed to queue game object for deletion
    pub fn removeGameObjectByTag(self: *Scene, tag: []const u8) SceneError!void {
        const game_object = self.popGameObjectByOption(.{ .Tag = tag }) orelse return SceneError.GameObjectDoesNotExist;
        try self.queueGameObjectForDeletion(game_object);
    }
    //#endregion

    //#region Get functions
    pub fn getGameObjectById(self: *Scene, id: usize) ?*GameObject {
        for (self.active_game_objects.items) |item| {
            if (item.unique_id == id) return item;
        }

        return null;
    }

    pub fn getGameObjectByName(_: *Scene, _: []const u8) ?*GameObject {}

    pub fn getGameObjectByTag(_: *Scene, _: []const u8) ?*GameObject {}

    /// Returns all active game objects
    pub fn getActiveGameObjects(self: *Scene) !ArrayList(*GameObject) {
        var game_objects: ArrayList(*GameObject) = try ArrayList(*GameObject).initCapacity(std.heap.c_allocator, self.active_game_objects.items.len / 2);

        for (self.active_game_objects.items) |item| {
            if (item.is_active) game_objects.append(std.heap.c_allocator, item) catch {};
        }

        return game_objects;
    }
    //#endregion

    // --------------------------- HELPER FUNCTIONS --------------------------- //
    /// Aquires lock on active game objects until it removes game object from list
    ///
    /// ### Arguments
    /// - `id`: Game object id
    ///
    /// ### Returns
    /// - `*GameObject`: The removed game object
    fn popGameObjectByOption(self: *Scene, option: PopGameObjectOption) ?*GameObject {
        self.active_game_objects_mutex.lock();
        defer self.active_game_objects_mutex.unlock();

        const filter_fn = struct {
            inline fn filter(game_object: *GameObject, opt: PopGameObjectOption) bool {
                switch (opt) {
                    .Id => |id| return game_object.unique_id == id,
                    .Name => |name| return if (game_object.name != null) std.mem.eql(u8, game_object.name.?, name) else false,
                    .Tag => |tag| return if (game_object.tag != null) std.mem.eql(u8, game_object.tag.?, tag) else false,
                }
            }
        }.filter;

        if (self.active_game_objects.items.len > 0) {
            for (self.active_game_objects.items, 0..) |item, index| {
                if (filter_fn(item, option)) {
                    return self.active_game_objects.swapRemove(index);
                }
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
    }

    /// This function is ran every frame before rendering
    fn onRequestFrameRender(_: void, data: ?*anyopaque) anyerror!void {
        const scene: *Scene = try caster.castFromNullableAnyopaque(Scene, data);

        scene.activateGameObjects();
        scene.clearInactiveGameObjects();

        // Generate spatial hash
        if (scene.spatial_hash) |hash|
            hash.deinit();

        scene.spatial_hash = try SpatialHash.create(&scene.options, 8);
        for (scene.active_game_objects.items) |item| {
            try scene.spatial_hash.?.add(item);
        }
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

const PopGameObjectOption = union(enum) {
    Id: usize,
    Name: []const u8,
    Tag: []const u8,
};
