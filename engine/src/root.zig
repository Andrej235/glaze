const std = @import("std");
const Debug = @import("debug/debug.zig").Debug;

const WL = @import("platform/linux/wayland.zig").Wayland;
const Renderer = @import("renderer/renderer.zig").Renderer;
const Scene = @import("scene-manager/scene.zig").Scene;

const GameObject = @import("scene-manager/game_object.zig").GameObject;
const Transform = @import("components/transform.zig").Transform;
const BoxCollider2d = @import("components/box-collider-2d.zig").BoxCollider2D;
const Rigidbody = @import("components/rigidbody-2d.zig").Rigidbody2D;
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
    const tr = try go.addComponent(Transform);
    _ = tr.position.setXYZ(3, 0, 0);
    _ = try go.addComponent(BoxCollider2d);
    _ = try go.addComponent(SpriteRenderer("src/assets/textures/logo.png"));
    _ = try go.addComponent(Player);
    const rb = try go.addComponent(Rigidbody);
    _ = rb.gravity.setScalar(0);

    const count = 5;
    for (0..count) |_| {
        createObj(scene) catch unreachable;
    }

    const floor = try scene.addGameObject();
    const floor_tr = try floor.addComponent(Transform);
    _ = try floor.addComponent(SpriteRenderer("src/assets/textures/circle.png"));
    _ = try floor.addComponent(BoxCollider2d);
    floor_tr.position.y = -3;
    floor_tr.scale.x = 15;

    const camera = scene.addGameObject() catch unreachable;
    _ = try camera.addComponent(Transform);
    _ = try camera.addComponent(Camera2D);
    scene.makeCameraCurrent(camera);

    //#endregion

    while (true) {
        std.Thread.sleep(1_000_000_000);
    }
}

fn createObj(scene: *Scene) !void {
    const rand = std.crypto.random;

    const x = try scene.addGameObject();
    const t = try x.addComponent(Transform);
    const r = try x.addComponent(SpriteRenderer("src/assets/textures/circle.png"));
    _ = try x.addComponent(BoxCollider2d);
    _ = try x.addComponent(Rigidbody);

    t.position.x = rand.float(f32) * 10 - 5;
    t.position.y = rand.float(f32) * 5 + 3;

    r.setColor(@constCast(&Vector4.fromXYZW(rand.float(f32), rand.float(f32), rand.float(f32), 1.0)));
}

const Player = struct {
    game_object: ?*GameObject = null,

    pub fn create(ptr: *Player) !void {
        ptr.* = Player{};
    }

    pub fn update(self: *Player, _: f32) !void {
        const input = self.game_object.?.input;

        var dir = Vector3.fromScalar(0);
        if (input.isPressed(.A)) dir.x -= 1;
        if (input.isPressed(.D)) dir.x += 1;
        if (input.isPressed(.W)) dir.y += 1;
        if (input.isPressed(.S)) dir.y -= 1;

        // const transform = self.game_object.?.getComponent(Transform) orelse unreachable;
        // _ = transform.position.add(dir.normalize().mulScalar(deltatime * 3));

        const rb = self.game_object.?.getComponent(Rigidbody) orelse unreachable;
        rb.velocity = dir.normalize().mulScalar(3).*;
    }
};
