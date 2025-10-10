const std = @import("std");

const arena_allocator_util = @import("utils/arena_allocator_util.zig");
const allocateNewArena = arena_allocator_util.allocateNewArena;

const Renderer = @import("renderer/renderer.zig").Renderer;
const EventManager = @import("event-system/event_manager.zig").EventManager;
const SceneManager = @import("scene-manager/scene_manager.zig").SceneManager;
const InputSystem = @import("input-system/input.zig").InputSystem;

pub const App = struct {
    renderer: *Renderer,

    event_system: *EventManager,
    event_system_arena: std.heap.ArenaAllocator,

    scene_manager: *SceneManager,
    scene_manager_arena: std.heap.ArenaAllocator,

    input_system: *InputSystem,
    input_system_arena: std.heap.ArenaAllocator,

    pub fn create() !*App {

        // Create main app instance
        const app_instance: *App = try std.heap.page_allocator.create(App);

        // Create event manager instance
        const event_manager_arena: *std.heap.ArenaAllocator = try allocateNewArena();
        const event_manager: *EventManager = try std.heap.page_allocator.create(EventManager);
        event_manager.* = try EventManager.create(event_manager_arena, app_instance);
        try event_manager.startThread();

        const renderer = try Renderer.init(.{
            .height = 800,
            .width = 800,
            .title = "My New Game",
        });

        // Create scene manager instance
        const scene_manager_arena: *std.heap.ArenaAllocator = try allocateNewArena();
        const scene_manager: *SceneManager = try std.heap.page_allocator.create(SceneManager);
        scene_manager.* = SceneManager.create(scene_manager_arena, app_instance);

        // Create input system instance
        const input_system_arena: *std.heap.ArenaAllocator = try allocateNewArena();
        const input_system: *InputSystem = try std.heap.page_allocator.create(InputSystem);
        input_system.* = try InputSystem.create(input_system_arena);

        app_instance.* = App{
            .renderer = renderer,
            .event_system = event_manager,
            .event_system_arena = event_manager_arena.*,
            .scene_manager = scene_manager,
            .scene_manager_arena = scene_manager_arena.*,
            .input_system = input_system,
            .input_system_arena = input_system_arena.*,
        };

        return app_instance;
    }

    pub fn getRenderer(self: *App) *Renderer {
        return self.renderer;
    }

    pub fn getEventManager(self: *App) *EventManager {
        return self.event_system;
    }
};
