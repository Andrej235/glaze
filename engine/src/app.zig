const std = @import("std");

const Window = @import("ui/window.zig").Window;
const EventManager = @import("event-system/event_manager.zig").EventManager;
const RenderSystem = @import("render-system/render_system.zig").RenderSystem;

pub const App = struct {
    arena_allocator: std.heap.ArenaAllocator,

    window: *Window,
    window_arena: std.heap.ArenaAllocator,

    event_system: *EventManager,
    event_system_arena: std.heap.ArenaAllocator,

    render_system: *RenderSystem,
    render_system_arena: std.heap.ArenaAllocator,

    pub fn create() !*App {
        
        // Create main app instance
        const app_instance: *App = try std.heap.page_allocator.create(App);


        // Create event manager instance
        const event_manager_arena: *std.heap.ArenaAllocator = try std.heap.page_allocator.create(std.heap.ArenaAllocator);
        event_manager_arena.* = std.heap.ArenaAllocator.init(std.heap.page_allocator);

        const event_manager: *EventManager = try std.heap.page_allocator.create(EventManager);
        event_manager.* = try EventManager.create(event_manager_arena, app_instance);


        // Create render system instance
        const render_system_arena: *std.heap.ArenaAllocator = try std.heap.page_allocator.create(std.heap.ArenaAllocator);
        render_system_arena.* = std.heap.ArenaAllocator.init(std.heap.page_allocator);

        const render_system: *RenderSystem = try std.heap.page_allocator.create(RenderSystem);
        render_system.* = try RenderSystem.create(render_system_arena, app_instance);


        // Create window instance
        const window_arena: *std.heap.ArenaAllocator = try std.heap.page_allocator.create(std.heap.ArenaAllocator);
        window_arena.* = std.heap.ArenaAllocator.init(std.heap.page_allocator);

        const window: *Window = try std.heap.page_allocator.create(Window);
        window.* = try Window.create(window_arena, app_instance, event_manager.getWindowEvents());
        try window.initPlatformWindow("Glaze Game", 800, 800);


        app_instance.* = App{
            .arena_allocator = window_arena.*,
            .window = window,
            .window_arena = window_arena.*,
            .event_system = event_manager,
            .event_system_arena = event_manager_arena.*,
            .render_system = render_system,
            .render_system_arena = render_system_arena.*
        };

        return app_instance;
    }

    pub fn getWindow(self: *App) *Window {
        return self.window;
    }

    pub fn getRenderSystem(self: *App) *RenderSystem {
        return self.render_system;
    }

    pub fn getEventManager(self: *App) *EventManager {
        return self.event_system;
    }
};