const std = @import("std");

const caster = @import("utils/caster.zig");
const event_manager = @import("event-system/event_manager.zig");

const App = @import("app.zig").App;
const DynString = @import("utils/dyn_string.zig").DynString;
const Square = @import("scene-manager/objects/square.zig").Square;
const KeyCode = @import("event-system/models/key_code.zig").KeyCode;
const GameObject = @import("scene-manager/game_object.zig").GameObject;
const Scene = @import("scene-manager/scene.zig").Scene;

const size: usize = 100_000;

pub fn setup(app: *App) !void {
    const scene = app.getRenderSystem();

    // Create player 1
    const player1: *GameObject = scene.addEntity() catch |e| {
        std.log.err("Failed to add player 1 entity: {}", .{e});
        return;
    };

    _ = player1.addComponent(Player1Script);
    var player1_square = player1.addComponent(Square).?.getUnderlyingComponentAsType(Square);
    player1_square.red = 1.0;

    // Create player 2
    const player2: *GameObject = scene.addEntity() catch |e| {
        std.log.err("Failed to add player 2 entity: {}", .{e});
        return;
    };

    _ = player2.addComponent(Player2Script);
    var player2_square = player2.addComponent(Square).?.getUnderlyingComponentAsType(Square);
    player2_square.blue = 1.0;
}

const Player1Script = struct {
    game_object: ?*GameObject = null,

    pub fn create(ptr: *Player1Script) !void {
        ptr.* = Player1Script{};
    }

    pub fn update(self: *Player1Script, deltatime: f64) !void {
        const input = self.game_object.?.input;
        var square = self.game_object.?
            .findComponentByType(Square).?
            .getUnderlyingComponentAsType(Square);

        var dx: f32 = 0.0;
        var dy: f32 = 0.0;

        if (input.isPressed(KeyCode.W)) dy += 1.0;
        if (input.isPressed(KeyCode.S)) dy -= 1.0;
        if (input.isPressed(KeyCode.A)) dx -= 1.0;
        if (input.isPressed(KeyCode.D)) dx += 1.0;

        if (dx != 0 or dy != 0) {
            const length = @sqrt(dx * dx + dy * dy);
            dx /= length;
            dy /= length;

            const delta_s: f32 = @floatCast(deltatime / 1000.0);
            const speed: f32 = 2.0;

            square.x += dx * speed * delta_s;
            square.y += dy * speed * delta_s;
        }
    }

    pub fn destroy(_: *Player1Script) !void {}
};

const Player2Script = struct {
    game_object: ?*GameObject = null,

    pub fn create(ptr: *Player2Script) !void {
        ptr.* = Player2Script{};
    }

    pub fn update(self: *Player2Script, deltatime: f64) !void {
        const input = self.game_object.?.input;
        var square = self.game_object.?
            .findComponentByType(Square).?
            .getUnderlyingComponentAsType(Square);

        var dx: f32 = 0.0;
        var dy: f32 = 0.0;

        if (input.isPressed(KeyCode.Up)) dy += 1.0;
        if (input.isPressed(KeyCode.Down)) dy -= 1.0;
        if (input.isPressed(KeyCode.Left)) dx -= 1.0;
        if (input.isPressed(KeyCode.Right)) dx += 1.0;

        if (dx != 0 or dy != 0) {
            const length = @sqrt(dx * dx + dy * dy);
            dx /= length;
            dy /= length;

            const delta_s: f32 = @floatCast(deltatime / 1000.0);
            const speed: f32 = 2.0;

            square.x += dx * speed * delta_s;
            square.y += dy * speed * delta_s;
        }
    }

    pub fn destroy(_: *Player2Script) !void {}
};
