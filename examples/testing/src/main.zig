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

    const ui_root = try glaze.UINode.createElement();
    ui_root.element.style.display = .block;
    ui_root.element.style.width = .{ .vw = 100 };
    ui_root.element.style.height = .{ .keyword = .auto };
    ui_root.element.style.background_color = .{ 0.1, 0.5, 0.7, 1 };

    const child1 = try glaze.UINode.createElement();
    child1.element.style.display = .block;
    child1.element.style.width = .{ .px = 100 };
    child1.element.style.height = .{ .px = 100 };
    child1.element.style.background_color = .{ 0.5, 0.5, 0.5, 1 };

    const child2 = try glaze.UINode.createElement();
    child2.element.style.display = .block;
    child2.element.style.width = .{ .rem = 4 };
    child2.element.style.height = .{ .rem = 4 };
    child2.element.style.background_color = .{ 0.5, 1, 0.5, 1 };
    child2.element.style.margin = .{ .{ .px = 15 }, .{ .px = 5 }, .{ .px = 15 }, .{ .px = 5 } };

    const child3 = try glaze.UINode.createElement();
    child3.element.style.display = .block;
    child3.element.style.width = .{ .px = 150 };
    child3.element.style.height = .{ .px = 100 };
    child3.element.style.background_color = .{ 1, 0.5, 0.5, 1 };
    child3.element.style.padding = .{ .{ .px = 10 }, .{ .px = 10 }, .{ .px = 10 }, .{ .px = 10 } };

    const nested_child = try glaze.UINode.createElement();
    nested_child.element.style.display = .@"inline-block";
    nested_child.element.style.width = .{ .px = 50 };
    nested_child.element.style.height = .{ .px = 50 };
    nested_child.element.style.background_color = .{ 0.5, 0.5, 1, 0.4 };
    try child3.element.addChild(nested_child);

    const nested_child2 = try glaze.UINode.createElement();
    nested_child2.element.style.display = .@"inline-block";
    nested_child2.element.style.width = .{ .px = 50 };
    nested_child2.element.style.height = .{ .px = 50 };
    nested_child2.element.style.background_color = .{ 0.5, 0.5, 1, 0.4 };
    nested_child2.element.style.margin = .{ .{ .px = 0 }, .{ .px = 0 }, .{ .px = 0 }, .{ .px = 10 } };
    try child3.element.addChild(nested_child2);

    const child4 = try glaze.UINode.createElement();
    child4.element.style.display = .@"inline-block";
    child4.element.style.width = .{ .px = 100 };
    child4.element.style.height = .{ .px = 70 };
    child4.element.style.background_color = .{ 0.8, 0.7, 0.2, 1 };
    child4.element.style.margin = .{ .{ .px = 10 }, .{ .px = 10 }, .{ .px = 10 }, .{ .px = 10 } };

    const child5 = try glaze.UINode.createElement();
    child5.element.style.display = .block;
    child5.element.style.width = .{ .px = 350 };
    child5.element.style.height = .{ .px = 30 };
    child5.element.style.background_color = .{ 1, 0.5, 1, 1 };

    try ui_root.element.addChild(child1);
    try ui_root.element.addChild(child2);
    try ui_root.element.addChild(child3);
    try ui_root.element.addChild(child4);
    try ui_root.element.addChild(child5);

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
        // _ = try audio_source.playSound(.{
        //     .file_path = "src/assets/sfx/gone-with-the-wind.mp3",
        //     .flags = .{
        //         .looping = true,
        //         .stream = true,
        //     },
        //     .volume = 0.25,
        // });
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
