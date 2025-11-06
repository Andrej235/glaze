const std = @import("std");
const glaze = @import("glaze");

pub fn main() !void {
    const app = try glaze.App.create();
    // glaze.Debug.toggleFpsLogging();

    //#region test scene
    const scene = try app.scene_manager.createScene(.{
        .name = "scene-1",
        .world_width = 1000,
        .world_height = 1000,
        .spatial_hash_cell_size = 1,
    });
    try app.scene_manager.setActiveScene("scene-1");

    const camera = scene.addGameObject() catch unreachable;
    _ = try camera.addComponent(glaze.Transform);
    // _ = try camera.addComponent(glaze.Camera2D);
    _ = try camera.addComponent(glaze.AudioListener);
    // scene.makeCameraCurrent(camera);

    var font_manager = glaze.FontManager.init(std.heap.c_allocator);
    try font_manager.addFont("roboto-thin", "src/assets/fonts/atlas.png", "src/assets/fonts/atlas.json");
    const roboto = font_manager.getFont("roboto-thin") orelse unreachable;

    const ui_root = try glaze.UINode.createElement();
    try ui_root.element.addChild(try glaze.UINode.createTextNode("Hello World", roboto));
    scene.setUIRoot(ui_root);

    const player_object = try scene.addGameObject();
    const tr = try player_object.addComponent(glaze.Transform);
    _ = tr.position.setXYZ(3, 5, 0);
    _ = try player_object.addComponent(glaze.BoxCollider2d);
    _ = try player_object.addComponent(glaze.SpriteRenderer("src/assets/textures/logo.png"));
    const player_rb = try player_object.addComponent(glaze.Rigidbody);
    _ = try player_object.addComponent(glaze.AudioSource(null));
    _ = try player_object.addComponent(Player);

    _ = player_rb.gravity.setScalar(0);

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
    audio_source: *glaze.AudioSource(null) = undefined,
    app: *glaze.App = undefined,

    pub fn create(ptr: *Player) !void {
        ptr.* = Player{
            .app = glaze.App.get(),
        };
    }

    pub fn start(self: *Player) !void {
        const audio_source = self.game_object.?.getComponent(glaze.AudioSource(null)) orelse unreachable;
        self.audio_source = audio_source;
        _ = try audio_source.playSound(.{
            .file_path = "src/assets/sfx/gone-with-the-wind.mp3",
            .flags = .{
                .looping = true,
                .stream = true,
            },
            .volume = 0.25,
        });
    }

    pub fn update(self: *Player, deltatime: f32) !void {
        const input = self.game_object.?.input;

        var dir = glaze.Vector3.fromScalar(0);
        if (input.isPressed(.A)) dir.x -= 1;
        if (input.isPressed(.D)) dir.x += 1;
        if (input.isPressed(.W)) dir.y += 1;
        if (input.isPressed(.S)) dir.y -= 1;

        if (input.isPressed(.Space)) {
            _ = try self.app.sound_system.playSoundGlobally(.{ .file_path = "src/assets/sfx/boing-2.mp3" });
        }

        const transform = self.game_object.?.getComponent(glaze.Transform) orelse unreachable;
        _ = transform.position.add(dir.normalize().mulScalar(deltatime * 30));

        // const rb = self.game_object.?.getComponent(glaze.Rigidbody) orelse unreachable;
        // rb.velocity = dir.normalize().mulScalar(3).*;
    }
};
