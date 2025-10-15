const std = @import("std");

const caster = @import("utils/caster.zig");
const event_manager = @import("event-system/event_manager.zig");

const App = @import("app.zig").App;
const Scene = @import("scene-manager/scene.zig").Scene;
const DynString = @import("utils/dyn_string.zig").DynString;
const Transform = @import("components/transform.zig").Transform;
const Square = @import("scene-manager/objects/square.zig").Square;
const KeyCode = @import("input-system/keycode/keycode.zig").KeyCode;
const GameObject = @import("scene-manager/game_object.zig").GameObject;
const SceneManager = @import("scene-manager/scene_manager.zig").SceneManager;
const SpriteRenderer = @import("components/sprite-renderer.zig").SpriteRenderer;

const type_id = @import("utils/type-id.zig");
const typeId = type_id.typeId;

const size: usize = 10_000;

pub fn setup(app: *App) !void {
    const scene_manager = app.scene_manager;

    const scene = try app.scene_manager.createScene("scene-1");
    _ = try app.scene_manager.createScene("scene2");
    try app.scene_manager.setActiveScene("scene-1");

    for (0..size) |_| {
        // std.debug.print("Index: {}", .{i});
        const go2 = try scene.addGameObject();
        //go2.name = "player1";
        _ = try go2.addComponent(Transform);
        _ = try go2.addComponent(SpriteRenderer);
        _ = try go2.addComponent(Player1Script);
    }

    _ = try app.event_system.window_events.registerOnKeyDown(onDeleteScene, scene_manager);

    while (true) {
        std.Thread.sleep(2 * std.time.ns_per_week);
    }
}

fn onDeleteScene(key: KeyCode, data: ?*anyopaque) anyerror!void {
    const scene_manager = try caster.castFromNullableAnyopaque(SceneManager, data);

    // Delete -> Delete all entities
    if (key == .Delete) {
        const scene = try scene_manager.getActiveScene();

        for (0..size) |i| {
            try scene.removeGameObjectById(i);
        }
    }
    // Insert -> Create new entities
    else if (key == .Insert) {
        std.debug.print("Pressed", .{});
        const scene = try scene_manager.getActiveScene();

        for (0..size) |_| {
            // std.debug.print("Index: {}", .{i});
            const go2 = try scene.addGameObject();
            //go2.name = "player1";
            _ = try go2.addComponent(Transform);
            _ = try go2.addComponent(SpriteRenderer);
            _ = try go2.addComponent(Player1Script);
        }
    }
    // F1 -> Sets active scene to 'scene1'
    else if (key == .F1) {
        try scene_manager.setActiveScene("scene-1");
    }
    // F2 -> Sets active scene to 'scene2'
    else if (key == .F2) {
        try scene_manager.setActiveScene("scene2");
    }
    // F3 -> Remove first 10 elements
    else if (key == .F3) {
        const scene = try scene_manager.getActiveScene();

        for (0..10) |i| {
            try scene.removeGameObjectById(i);
        }
    }
    // F4 -> Remove game object by name 'player1'
    else if (key == .F4) {
        const scene = try scene_manager.getActiveScene();
        try scene.removeGameObjectByName("player1");
    }
    // F5 -> Destroy scene 'scene1'
    else if (key == .F5) {
        try scene_manager.setActiveScene("scene2");
        try scene_manager.removeScene("scene-1");
    }
    // F6 -> Pause all game objects
    else if (key == .F6) {
        const scene = try scene_manager.getActiveScene();

        for (0..size) |i| {
            const a = scene.getGameObjectById(i);
            a.?.setActive(false);
        }
    }
}

const Player1Script = struct {
    game_object: ?*GameObject = null,

    pub fn create(ptr: *Player1Script) !void {
        ptr.* = Player1Script{};
    }

    pub fn update(self: *Player1Script, deltatime: f32) !void {
        const input = self.game_object.?.input;

        var transform = self.game_object.?.getComponent(Transform) orelse return;

        var dx: f32 = 0.0;
        var dy: f32 = 0.0;

        if (input.isPressed(KeyCode.W)) dy += 1.0;
        if (input.isPressed(KeyCode.S)) dy -= 1.0;
        if (input.isPressed(KeyCode.A)) dx -= 1.0;
        if (input.isPressed(KeyCode.D)) dx += 1.0;

        const delta_s: f32 = @floatCast(deltatime / 1000.0);

        if (dx != 0 or dy != 0) {
            const length = @sqrt(dx * dx + dy * dy);
            dx /= length;
            dy /= length;

            const speed: f32 = 2.0;

            transform.position.x += dx * speed * delta_s;
            transform.position.y += dy * speed * delta_s;
        }

        if (input.isPressed(.Q))
            transform.rotation.z += delta_s;

        if (input.isPressed(.E))
            transform.rotation.z -= delta_s;
    }

    pub fn destroy(_: *Player1Script) !void {}
};
