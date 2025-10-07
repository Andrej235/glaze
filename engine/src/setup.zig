const std = @import("std");

const caster = @import("utils/caster.zig");
const event_manager = @import("event-system/event_manager.zig");

const App = @import("app.zig").App;
const DynString = @import("utils/dyn_string.zig").DynString;
const Square = @import("render-system/objects/square.zig").Square;
const KeyCode = @import("event-system/models/key_code.zig").KeyCode;
const GameObject = @import("render-system/game_object.zig").GameObject;
const RenderSystem = @import("render-system/render_system.zig").RenderSystem;

const size: usize = 100_000;

pub fn setup(app: *App) !void {
    
    const render_system = app.getRenderSystem();

    const player1: *GameObject = try render_system.addEntity();
    player1.addComponent(Player1Script);
    player1.addComponent(Square);

    const player2: *GameObject = try render_system.addEntity();
    player2.addComponent(Player2Script);
    player2.addComponent(Square);
}

const Player1Script = struct {
    game_object: ?*GameObject = null,
    
    pub fn create(ptr: *Player1Script) !void {
        ptr.* = Player1Script{};
    }

    pub fn update(self: *Player1Script, _: f64) !void {
        const input = self.game_object.? .input;
        var square = self.game_object.? 
            .findComponentByType(Square).? 
            .getUnderlyingComponentAsType(Square);

        var dx: f32 = 0.0;
        var dy: f32 = 0.0;

        if (input.isPressed(KeyCode.W)) dy += 1.0;  // Up
        if (input.isPressed(KeyCode.S)) dy -= 1.0;  // Down
        if (input.isPressed(KeyCode.A)) dx -= 1.0;  // Left
        if (input.isPressed(KeyCode.D)) dx += 1.0;  // Right

        // If both dx and dy are non-zero, normalize to prevent faster diagonal movement
        if (dx != 0 or dy != 0) {
            const length = @sqrt(dx*dx + dy*dy);
            dx /= length;
            dy /= length;
            
            // Move the square
            square.x += dx * 0.01;
            square.y += dy * 0.01;
        }
    }

    pub fn destroy(_: *Player1Script) !void { }
};

const Player2Script = struct {
    game_object: ?*GameObject = null,
    
    pub fn create(ptr: *Player2Script) !void {
        ptr.* = Player2Script{};
    }

    pub fn update(self: *Player2Script, _: f64) !void {
        const input = self.game_object.? .input;
        var square = self.game_object.? 
            .findComponentByType(Square).? 
            .getUnderlyingComponentAsType(Square);

        var dx: f32 = 0.0;
        var dy: f32 = 0.0;

        if (input.isPressed(KeyCode.Up)) dy += 1.0;  // Up
        if (input.isPressed(KeyCode.Down)) dy -= 1.0;  // Down
        if (input.isPressed(KeyCode.Left)) dx -= 1.0;  // Left
        if (input.isPressed(KeyCode.Right)) dx += 1.0;  // Right

        // If both dx and dy are non-zero, normalize to prevent faster diagonal movement
        if (dx != 0 or dy != 0) {
            const length = @sqrt(dx*dx + dy*dy);
            dx /= length;
            dy /= length;
            
            // Move the square
            square.x += dx * 0.01;
            square.y += dy * 0.01;
        }
    }

    pub fn destroy(_: *Player2Script) !void { }
};