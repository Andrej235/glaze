const std = @import("std");

const ArrayList = std.ArrayList;

const App = @import("../app.zig").App;
const GameObject = @import("game_object.zig").GameObject;

pub const RenderSystem = struct {
    arena_allocator: *std.heap.ArenaAllocator,
    gp_allocator: std.heap.GeneralPurposeAllocator(.{}),

    app: *App,

    next_id: usize,
    free_ids: ArrayList(usize),
    game_objects: ArrayList(*GameObject),

    active_game_objects: usize = 0,

    mutex: std.Thread.Mutex,

    pub fn create(arena_allocator: *std.heap.ArenaAllocator, app: *App) !RenderSystem {
        return RenderSystem{
            .arena_allocator = arena_allocator,
            .gp_allocator = std.heap.GeneralPurposeAllocator(.{}){},
            .app = app,
            .next_id = 0,
            .free_ids = ArrayList(usize){},
            .game_objects = ArrayList(*GameObject){},
            .mutex = std.Thread.Mutex{},
        };
    }

    pub fn addEntity(self: *RenderSystem) !*GameObject {
        const allocator = self.arena_allocator.allocator();

        // Obtain thread lock to prevent race conditions
        self.mutex.lock();
        defer self.mutex.unlock();
        
        // Create new instance of game object
        const game_object = try allocator.create(GameObject);
        game_object.* = try GameObject.create(self.arena_allocator, self.app);

        // Assign id
        var id: usize = 0;

        if (self.free_ids.items.len > 0) {
            if (self.free_ids.pop()) |item| { id = item; } 
            else { return error.FalseFreeId; }
        } else {
            id = self.next_id;
            self.next_id += 1;
        }

        game_object.setId(id);

        try self.game_objects.append(allocator, game_object);

        self.active_game_objects += 1;

        return game_object;
    }

    pub fn removeEntity(self: *RenderSystem, id: usize) !void {
        const allocator = self.arena_allocator.allocator();

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

            // Free up game object memory
            try item.destroy();
            allocator.destroy(item);

            _ = self.game_objects.swapRemove(index_of_game_object);
            
            // Return id into list to be reused
            try self.free_ids.append(allocator, item_id);

            self.active_game_objects -= 1;
        }
    }
};