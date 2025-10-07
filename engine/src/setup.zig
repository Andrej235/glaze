const std = @import("std");

const caster = @import("utils/caster.zig");
const event_manager = @import("event-system/event_manager.zig");

const App = @import("app.zig").App;
const DynString = @import("utils/dyn_string.zig").DynString;
const Cube = @import("render-system/objects/cube.zig").Cube;
const KeyCode = @import("event-system/models/key_code.zig").KeyCode;
const GameObject = @import("render-system/game_object.zig").GameObject;
const RenderSystem = @import("render-system/render_system.zig").RenderSystem;

const size = 100_000;

pub fn setup(app: *App) !void {
    
    const render_system = app.getRenderSystem();
    const window_events = app.getEventManager().getWindowEvents();

    for (0..size) |_| {
        _ = try createComponent(render_system);
    }

    try window_events.registerOnKeyPressed(removeEntityFn, caster.castTPointerIntoAnyopaque(RenderSystem, app.getRenderSystem()));
}

const PlayerScript = struct {
    game_object: ?*GameObject = null,
    
    cached_time: f64,
    //something: *DynString,
    //anything: *DynString,

    pub fn create(ptr: *PlayerScript) !void {
        ptr.* = PlayerScript{
            .cached_time = 0,
            //.something = try DynString.initConstText("Something"),
            //.anything = try DynString.initConstText("Anything"),
        };
    }

    pub fn start(_: *PlayerScript) !void { 
    }

    pub fn update(self: *PlayerScript, deltatime: f64) !void {
        self.cached_time += deltatime;
    }

    pub fn destroy(_: *PlayerScript) !void { 
        //self.something.deinit();
        //self.anything.deinit();
    }
};

fn removeEntityFn(key: KeyCode, render_system_opq: ?*anyopaque) !void {
    switch (key) {
        .A => {
            const render_system: *RenderSystem = try caster.castFromNullableAnyopaque(RenderSystem, render_system_opq);
                
            std.debug.print("\nActive game objects: {}", .{render_system.active_game_objects});
            std.debug.print("\nSize of game objects: {}", .{render_system.game_objects.items.len});

            for (0..size) |i| {
                try render_system.removeEntity(i);
            }

            std.debug.print("\n\nActive game objects: {}", .{render_system.active_game_objects});
            std.debug.print("\nSize of game objects: {}", .{render_system.game_objects.items.len});
            std.debug.print("\nFree ids: {}", .{render_system.free_ids.items.len});
        },
        .D => {
            const render_system: *RenderSystem = try caster.castFromNullableAnyopaque(RenderSystem, render_system_opq);
            
            for (0..size) |_| {
                _ = try createComponent(render_system);
            }
        },
        else => {},
    }
}

fn createComponent(render_system: *RenderSystem) !*GameObject {
    const entity: *GameObject = try render_system.addEntity();
    try entity.addComponent(PlayerScript);
    //try entity.name.setConstText("Cube");
    return entity;
}