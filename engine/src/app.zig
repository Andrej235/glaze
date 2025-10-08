const std = @import("std");

const arena_allocator_util = @import("utils/arena_allocator_util.zig");
const allocateNewArena = arena_allocator_util.allocateNewArena;

const Window = @import("ui/window.zig").Window;
const EventManager = @import("event-system/event_manager.zig").EventManager;
const SceneManager = @import("scene-manager/scene_manager.zig").SceneManager;
const InputSystem = @import("scene-manager/input-system/input.zig").InputSystem;

pub const App = struct {
    arena_allocator: std.heap.ArenaAllocator,

    window: *Window,
    window_arena: std.heap.ArenaAllocator,

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

        // Create window instance
        const window_arena: *std.heap.ArenaAllocator = try allocateNewArena();
        const window: *Window = try std.heap.page_allocator.create(Window);
        window.* = try Window.create(window_arena, app_instance, event_manager.getWindowEvents());
        try window.initPlatformWindow("Glaze Game", 800, 800);

        // Create scene manager instance
        const scene_manager_arena: *std.heap.ArenaAllocator = try allocateNewArena();
        const scene_manager: *SceneManager = try std.heap.page_allocator.create(SceneManager);
        scene_manager.* = SceneManager.create(scene_manager_arena, app_instance);

        // Create input system instance
        const input_system_arena: *std.heap.ArenaAllocator = try allocateNewArena();
        const input_system: *InputSystem = try std.heap.page_allocator.create(InputSystem);
        input_system.* = try InputSystem.create(input_system_arena);

        app_instance.* = App{
            .arena_allocator = window_arena.*,
            .window = window,
            .window_arena = window_arena.*,
            .event_system = event_manager,
            .event_system_arena = event_manager_arena.*,
            .scene_manager = scene_manager,
            .scene_manager_arena = scene_manager_arena.*,
            .input_system = input_system,
            .input_system_arena = input_system_arena.*,
        };

        return app_instance;
    }

    pub fn getWindow(self: *App) *Window {
        return self.window;
    }

    pub fn getEventManager(self: *App) *EventManager {
        return self.event_system;
    }
};
