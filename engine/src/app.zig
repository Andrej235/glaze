const std = @import("std");

const zaudio = @import("zaudio");

const arena_allocator_util = @import("utils/arena-allocator-util.zig");
const allocateNewArena = arena_allocator_util.allocateNewArena;

const Renderer = @import("renderer/renderer.zig").Renderer;
const EventManager = @import("event-system/event-manager.zig").EventManager;
const SceneManager = @import("scenes/scene-manager.zig").SceneManager;
const InputSystem = @import("input-system/input.zig").InputSystem;
const PhysicsEngine = @import("physics-engine/physics-engine.zig").PhysicsEngine;
const SoundSystem = @import("sound-system/sound-system.zig").SoundSystem;

pub var app: ?*App = null;

pub const App = struct {
    renderer: *Renderer,
    sound_system: *SoundSystem,

    event_system: *EventManager,
    event_system_arena: std.heap.ArenaAllocator,

    scene_manager: *SceneManager,
    scene_manager_arena: std.heap.ArenaAllocator,

    input_system: *InputSystem,
    input_system_arena: std.heap.ArenaAllocator,

    pub fn create() !*App {
        const app_instance: *App = try std.heap.page_allocator.create(App);
        app = app_instance;

        // Create event manager instance
        const event_manager_arena: *std.heap.ArenaAllocator = try allocateNewArena();
        const event_manager: *EventManager = try std.heap.page_allocator.create(EventManager);
        event_manager.* = try EventManager.create(event_manager_arena, app_instance);
        try event_manager.startThread();

        // Create scene manager instance
        const scene_manager_arena: *std.heap.ArenaAllocator = try allocateNewArena();
        const scene_manager: *SceneManager = try std.heap.page_allocator.create(SceneManager);
        scene_manager.* = SceneManager.create(scene_manager_arena, app_instance);

        // Create input system instance
        const input_system_arena: *std.heap.ArenaAllocator = try allocateNewArena();
        const input_system: *InputSystem = try std.heap.page_allocator.create(InputSystem);
        input_system.* = try InputSystem.create(input_system_arena);

        app_instance.* = App{
            .renderer = undefined,
            .sound_system = undefined,

            .event_system = event_manager,
            .event_system_arena = event_manager_arena.*,

            .scene_manager = scene_manager,
            .scene_manager_arena = scene_manager_arena.*,

            .input_system = input_system,
            .input_system_arena = input_system_arena.*,
        };

        // renderer requires an initialized input to be set inside of the app singleton instance
        app_instance.renderer = try Renderer.init(.{
            .height = 1000,
            .width = 1000,
            .title = "My New Game",
        });

        // Create sound system instance
        app_instance.sound_system = try SoundSystem.create();

        return app_instance;
    }

    pub fn getRenderer(self: *App) *Renderer {
        return self.renderer;
    }

    pub fn getEventManager(self: *App) *EventManager {
        return self.event_system;
    }

    pub fn get() *App {
        if (app) |ptr| {
            return ptr;
        } else {
            return create() catch unreachable;
        }
    }
};
