const std = @import("std");
const glaze = @import("glaze");

pub fn main() !void {
    const app = try glaze.App.create();
    glaze.Debug.toggleFpsLogging();

    //#region test scene
    const scene = try app.scene_manager.createScene(.{
        .name = "scene-1",
        .world_width = 1000,
        .world_height = 1000,
        .spatial_hash_cell_size = 1,
    });
    try app.scene_manager.setActiveScene("scene-1");

    _ = try app.sound_system.playSoundGlobally(.{
        .file_path = "src/assets/sfx/gone-with-the-wind.mp3",
        .flags = .{
            .looping = true,
            .stream = true,
        },
        .volume = 0.25,
    });

    const go = try scene.addGameObject();
    const tr = try go.addComponent(glaze.Transform);
    _ = tr.position.setXYZ(3, 5, 0);
    _ = try go.addComponent(glaze.BoxCollider2d);
    _ = try go.addComponent(glaze.SpriteRenderer("src/assets/textures/logo.png"));
    _ = try go.addComponent(Player);
    _ = try go.addComponent(glaze.Rigidbody);

    const count = 10;
    for (0..count) |_| {
        createObj(scene) catch unreachable;
    }

    const floor = try scene.addGameObject();
    const floor_tr = try floor.addComponent(glaze.Transform);
    _ = try floor.addComponent(glaze.SpriteRenderer("src/assets/textures/circle.png"));
    _ = try floor.addComponent(glaze.BoxCollider2d);
    floor_tr.position.y = -3;
    floor_tr.scale.x = 15;

    const camera = scene.addGameObject() catch unreachable;
    _ = try camera.addComponent(glaze.Transform);
    _ = try camera.addComponent(glaze.Camera2D);
    scene.makeCameraCurrent(camera);

    //#endregion

    while (true) {
        std.Thread.sleep(1_000_000_000);
    }
}

fn createObj(scene: *glaze.Scene) !void {
    const rand = std.crypto.random;

    const x = try scene.addGameObject();
    const t = try x.addComponent(glaze.Transform);
    const r = try x.addComponent(glaze.SpriteRenderer("src/assets/textures/circle.png"));
    _ = try x.addComponent(glaze.BoxCollider2d);
    _ = try x.addComponent(glaze.Rigidbody);

    t.position.x = rand.float(f32) * 7 - 3.5;
    t.position.y = rand.float(f32) * 5 + 3;

    _ = t.scale.setScalar(rand.float(f32) * 0.3 + 0.2);

    r.setColor(@constCast(&glaze.Vector4.fromXYZW(rand.float(f32), rand.float(f32), rand.float(f32), 1.0)));
}

const Player = struct {
    game_object: ?*glaze.GameObject = null,
    app: *glaze.App = undefined,

    pub fn create(ptr: *Player) !void {
        ptr.* = Player{
            .app = glaze.App.get(),
        };
    }

    pub fn update(self: *Player, _: f32) !void {
        const input = self.game_object.?.input;

        var dir = glaze.Vector3.fromScalar(0);
        if (input.isPressed(.A)) dir.x -= 1;
        if (input.isPressed(.D)) dir.x += 1;
        if (input.isPressed(.W)) dir.y += 1;
        if (input.isPressed(.S)) dir.y -= 1;

        if (input.isPressed(.Space)) {
            _ = try self.app.sound_system.playSoundGlobally(.{ .file_path = "src/assets/sfx/boing-2.mp3" });
        }

        // const transform = self.game_object.?.getComponent(Transform) orelse unreachable;
        // _ = transform.position.add(dir.normalize().mulScalar(deltatime * 3));

        // const rb = self.game_object.?.getComponent(glaze.Rigidbody) orelse unreachable;
        // rb.velocity = dir.normalize().mulScalar(3).*;
    }
};
