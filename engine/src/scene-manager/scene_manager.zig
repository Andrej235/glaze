const std = @import("std");

const arena_allocator_util = @import("../utils/arena_allocator_util.zig");
const allocateNewArena = arena_allocator_util.allocateNewArena;
const freeArenaWithPageAllocator = arena_allocator_util.freeArenaWithPageAllocator;

const App = @import("../app.zig").App;
const Scene = @import("./scene.zig").Scene;

pub const SceneManager = struct {
    arena_allocator: *std.heap.ArenaAllocator,

    app: *App,

    active_scene: ?*Scene,
    scenes: std.StringHashMap(*Scene),

    mutex: std.Thread.Mutex,

    pub fn create(arena: *std.heap.ArenaAllocator, app: *App) SceneManager {
        return SceneManager{
            .arena_allocator = arena,
            .app = app,
            .active_scene = null,
            .scenes = std.StringHashMap(*Scene).init(arena.allocator()),
            .mutex = std.Thread.Mutex{},
        };
    }

    /// Creates new scene
    ///
    /// # Arguments
    /// - `name`: Name of the scene
    ///
    /// # Returns
    /// - `*Scene`: The created scene
    ///
    /// # Errors
    /// - `SceneAlreadyExists`: Scene with given name already exists
    /// - `SceneArenaMemoryAllocationFailed`: Failed to allocate memory for scene arena
    /// - `SceneMemoryAllocationFailed`: Failed to allocate memory for scene
    /// - `SceneCreationFailed`: Failed to create scene instance
    /// - `SceneAppendFailed`: Failed to append scene
    pub fn createScene(self: *SceneManager, name: []const u8) SceneManagerError!*Scene {
        const allocator = self.arena_allocator.allocator();

        self.mutex.lock();
        defer self.mutex.unlock();

        // Make sure that scene does not exist
        if (self.scenes.contains(name)) {
            return SceneManagerError.SceneAlreadyExists;
        }

        // Allocate memory for scene
        const scene_arena: *std.heap.ArenaAllocator = allocateNewArena() catch return SceneManagerError.SceneArenaMemoryAllocationFailed;
        const n_scene: *Scene = allocator.create(Scene) catch {
            freeArenaWithPageAllocator(scene_arena);
            return SceneManagerError.SceneMemoryAllocationFailed;
        };

        // Create new scene instance
        n_scene.* = Scene.create(name, self.app, scene_arena) catch {
            allocator.destroy(n_scene);
            return SceneManagerError.SceneCreationFailed;
        };

        // Try to append scene
        self.scenes.put(name, n_scene) catch {
            self.freeScene(n_scene);
            return SceneManagerError.SceneAppendFailed;
        };

        return n_scene;
    }

    /// Removes scene
    ///
    /// # Arguments
    /// - `name`: Name of the scene
    ///
    /// # Errors
    /// - `SceneDoesNotExist`: Scene with given name does not exist
    /// - `SceneIsActive`: Scene is active
    pub fn removeScene(self: *SceneManager, name: []const u8) SceneManagerError!void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Make sure that scene is not active
        if (self.active_scene != null and std.mem.eql(u8, self.active_scene.?.name, name)) {
            return SceneManagerError.SceneIsActive;
        }

        // Remove scene
        const scene = self.findScene(name) orelse return SceneManagerError.SceneDoesNotExist;
        self.freeScene(scene);
    }

    /// Finds scene
    ///
    /// # Arguments
    /// - `name`: Name of the scene
    ///
    /// # Returns
    /// - `*Scene`: The found scene
    pub fn findScene(self: *SceneManager, name: []const u8) ?*Scene {
        if (self.scenes.get(name)) |scene| {
            return scene;
        } else {
            return null;
        }
    }

    /// Sets active scene
    ///
    /// # Arguments
    /// - `name`: Name of the scene
    ///
    /// # Errors
    /// - `SceneDoesNotExist`: Scene with given name does not exist
    pub fn setActiveScene(self: *SceneManager, name: []const u8) SceneManagerError!void {
        // Call unload on active scene
        if (self.active_scene) |scene| scene.unload() catch return SceneManagerError.FailedToUnloadActiveScene;

        // Set active scene and call load on it
        if (self.findScene(name)) |scene| {
            self.active_scene = scene;
            scene.load() catch return SceneManagerError.FailedToLoadActiveScene;
        } else return SceneManagerError.SceneDoesNotExist;
    }

    /// Returns active scene
    pub fn getActiveScene(self: *SceneManager) !*Scene {
        if (self.active_scene == null) return SceneManagerError.SceneDoesNotExist;

        return self.active_scene.?;
    }

    // --------------------------- HELPER FUNCTIONS --------------------------- //
    fn freeScene(self: *SceneManager, scene: *Scene) void {
        scene.destroy();
        // _ = scene.gp_allocator.deinit();
        // scene.arena_allocator.deinit();
        //freeArenaWithPageAllocator(scene.arena_allocator);
        self.arena_allocator.allocator().destroy(scene);
    }
};

pub const SceneManagerError = error{
    SceneAlreadyExists,
    SceneDoesNotExist,
    SceneArenaMemoryAllocationFailed,
    SceneMemoryAllocationFailed,
    SceneCreationFailed,
    SceneAppendFailed,
    SceneIsActive,
    FailedToUnloadActiveScene,
    FailedToLoadActiveScene,
};
