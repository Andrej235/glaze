const std = @import("std");
const Debug = @import("debug/debug.zig").Debug;

const WL = @import("platform/linux/wayland.zig").Wayland;
const Renderer = @import("renderer/renderer.zig").Renderer;

const GameObject = @import("scene-manager/game_object.zig").GameObject;
const Transform = @import("components/transform.zig").Transform;
const BoxCollider2d = @import("components/box-collider-2d.zig").BoxCollider2D;
const SpriteRenderer = @import("components/sprite-renderer.zig").SpriteRenderer;
const Camera2D = @import("components/camera.zig").Camera2D;

const StandardMaterial = @import("materials/standard-material.zig").StandardMaterial;
const Vector3 = @import("vectors/vector3.zig").Vector3;
const Vector4 = @import("vectors/vector4.zig").Vector4;

const App = @import("app.zig").App;

pub fn main() !void {
    const app = try App.create();
    Debug.toggleFpsLogging();

    //#region test scene
    const scene = try app.scene_manager.createScene("scene-1");
    try app.scene_manager.setActiveScene("scene-1");
    const go = try scene.addGameObject();
    _ = try go.addComponent(Transform);
    _ = try go.addComponent(BoxCollider2d);
    _ = try go.addComponent(SpriteRenderer("src/assets/textures/logo.png"));
    _ = try go.addComponent(Player);

    const renderer = go.getComponent(SpriteRenderer("")) orelse unreachable;
    var newColor = Vector4.fromXYZW(1, 1, 0, 0.5);
    renderer.setColor(&newColor);

    const go2 = try scene.addGameObject();
    _ = try go2.addComponent(Transform);
    _ = try go2.addComponent(SpriteRenderer("src/assets/textures/circle.png"));
    _ = try go2.addComponent(BoxCollider2d);

    const renderer2 = go2.getComponent(SpriteRenderer("")) orelse unreachable;
    var newColor2 = Vector4.fromXYZW(1, 1, 0, 1);
    renderer2.setColor(&newColor2);

    const camera = scene.addGameObject() catch unreachable;
    _ = try camera.addComponent(Transform);
    _ = try camera.addComponent(Camera2D);

    scene.makeCameraCurrent(camera);

    const count = 0;
    for (0..count) |_| {
        const x = try scene.addGameObject();
        _ = try x.addComponent(Transform);
        _ = try x.addComponent(BoxCollider2d);
    }
    //#endregion

    while (true) {
        std.Thread.sleep(1_000_000_000);
    }
}

const Player = struct {
    game_object: ?*GameObject = null,

    pub fn create(ptr: *Player) !void {
        ptr.* = Player{};
    }

    pub fn update(self: *Player, deltatime: f64) !void {
        const input = self.game_object.?.input;
        const transform = self.game_object.?.getComponent(Transform) orelse unreachable;
        // transform.rotation.z += @floatCast(deltatime);

        var dir = Vector3.fromScalar(0);
        if (input.isPressed(.A)) dir.x -= 1;
        if (input.isPressed(.D)) dir.x += 1;
        if (input.isPressed(.W)) dir.y += 1;
        if (input.isPressed(.S)) dir.y -= 1;

        _ = transform.position.add(dir.normalize().mulScalar(@as(f32, @floatCast(deltatime)) * 3));
    }
};
