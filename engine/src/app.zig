const std = @import("std");

const Window = @import("ui/window.zig").Window;
const EventManager = @import("event-system/event_manager.zig").EventManager;
const RenderSystem = @import("render-system/render_system.zig").RenderSystem;

pub const App = struct {
    arena_allocator: std.heap.ArenaAllocator,

    window: *Window,
    event_system: *EventManager,
    render_system: *RenderSystem,

    pub fn create() !*App {
        var arena: *std.heap.ArenaAllocator = @constCast(&std.heap.ArenaAllocator.init(std.heap.page_allocator));
        const allocator = arena.allocator();
        
        // Create main app instance
        const app_instance: *App = try allocator.create(App);

        // Create event manager instance
        const event_manager: *EventManager = try allocator.create(EventManager);
        event_manager.* = try EventManager.create(arena, app_instance);

        // Create render system instance
        const render_system: *RenderSystem = try allocator.create(RenderSystem);
        render_system.* = try RenderSystem.create(arena, app_instance);

        // Create window instance
        const window: *Window = try allocator.create(Window);
        window.* = try Window.create(arena, app_instance, event_manager.getWindowEvents());
        try window.initPlatformWindow("Glaze Game", 800, 800);

        app_instance.* = App{
            .arena_allocator = arena.*,
            .window = window,
            .event_system = event_manager,
            .render_system = render_system,
        };

        return app_instance;
    }
};