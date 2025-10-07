const std = @import("std");

const caster = @import("utils/caster.zig");
const event_manager = @import("event-system/event_manager.zig");

const App = @import("app.zig").App;
const DynString = @import("utils/dyn_string.zig").DynString;
const Square = @import("render-system/objects/square.zig").Square;
const KeyCode = @import("event-system/models/key_code.zig").KeyCode;
const GameObject = @import("render-system/game_object.zig").GameObject;
const RenderSystem = @import("render-system/render_system.zig").RenderSystem;

const size = 100_000;

pub fn setup(app: *App) !void {
    
    const render_system = app.getRenderSystem();

    const player: *GameObject = try render_system.addEntity();
    try player.addComponent(PlayerScript);
    try player.addComponent(Square);

    //const window_events = app.getEventManager().getWindowEvents();
    //try window_events.registerOnKeyPressed(removeEntityFn, caster.castTPointerIntoAnyopaque(RenderSystem, app.getRenderSystem()));
}

const PlayerScript = struct {
    game_object: ?*GameObject = null,
    
    cached_time: f64,

    pub fn create(ptr: *PlayerScript) !void {
        ptr.* = PlayerScript{
            .cached_time = 0,
        };
    }

    pub fn start(_: *PlayerScript) !void { }

    pub fn update(self: *PlayerScript, _: f64) !void {
        const input = self.game_object.?.input;
        const validKeys: []const KeyCode = &[_]KeyCode{.W, .A, .S, .D};

        if (input.isComboPressed(&[_]KeyCode{validKeys[0], validKeys[1]})) {
            // Move UP + LEFT
        } else if (input.isComboPressed(&[_]KeyCode{validKeys[0], validKeys[3]})) {
            // Move UP + RIGHT
        } else if (input.isComboPressed(&[_]KeyCode{validKeys[2], validKeys[1]})) {
            // Move DOWN + LEFT
        } else if (input.isComboPressed(&[_]KeyCode{validKeys[2], validKeys[3]})) {
            // Move DOWN + RIGHT
        } else if (input.isPressed(validKeys[0])) {
            // Move UP
        } else if (input.isPressed(validKeys[1])) {
            // Move LEFT
        } else if (input.isPressed(validKeys[2])) {
            // Move DOWN
        } else if (input.isPressed(validKeys[3])) {
            // Move RIGHT
        }
    }

    pub fn destroy(_: *PlayerScript) !void { }
};

fn removeEntityFn(key: KeyCode, render_system_opq: ?*anyopaque) !void {
    switch (key) {
        .A => {
            const render_system: *RenderSystem = try caster.castFromNullableAnyopaque(RenderSystem, render_system_opq);
                
            for (0..size) |i| {
                try render_system.removeEntity(i);
            }
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