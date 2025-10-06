const std = @import("std");

const caster = @import("utils/caster.zig");
const event_manager = @import("event-system/event_manager.zig");

const App = @import("app.zig").App;
const DynString = @import("utils/dyn_string.zig").DynString;
const Cube = @import("render-system/objects/cube.zig").Cube;
const KeyCode = @import("event-system/models/key_code.zig").KeyCode;
const GameObject = @import("render-system/game_object.zig").GameObject;
const RenderSystem = @import("render-system/render_system.zig").RenderSystem;

pub fn setup(app: *App) !void {
    
    const render_system = app.getRenderSystem();
    const window_events = app.getEventManager().getWindowEvents();

    for (0..100_000) |i| {
        const entity: *GameObject = try render_system.addEntity();
        try entity.addComponent(PlayerScript);
        try entity.name.setText(try std.fmt.allocPrint(std.heap.page_allocator, "Index:{}", .{i}));
    }

    try window_events.registerOnKeyPressed(removeEntityFn, caster.castTPointerIntoAnyopaque(RenderSystem, app.getRenderSystem()));
}

const PlayerScript = struct {
    game_object: ?*GameObject = null,
    
    cached_time: f64,

    pub fn create(ptr: *PlayerScript) !void {
        ptr.* = PlayerScript{
            .cached_time = 0
        };
    }

    pub fn start(self: *PlayerScript) !void { 
        std.debug.print("\nGame object ID: {d}", .{self.game_object.?.id});
    }

    pub fn update(self: *PlayerScript, deltatime: f64) !void {
        self.cached_time += deltatime;
    }

    pub fn destroy(_: *PlayerScript) !void { }
};

fn removeEntityFn(key: KeyCode, render_system_opq: ?*anyopaque) !void {
    switch (key) {
        .A => {
            const render_system: *RenderSystem = try caster.castFromNullableAnyopaque(RenderSystem, render_system_opq);
            for (0..100_000) |i| {
                try render_system.removeEntity(i);
            }
        },
        .D => {
            for (0..100_000) |i| {
                const render_system: *RenderSystem = try caster.castFromNullableAnyopaque(RenderSystem, render_system_opq);
                const entity: *GameObject = try render_system.addEntity();
                try entity.addComponent(PlayerScript);
                try entity.name.setText(try std.fmt.allocPrint(std.heap.page_allocator, "Index:{}", .{i}));
            }
        },
        else => {},
    }
}