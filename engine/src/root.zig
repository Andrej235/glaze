const std = @import("std");
const Debug = @import("debug/debug.zig").Debug;

const WL = @import("platform/linux/wayland.zig").Wayland;
const Renderer = @import("renderer/renderer.zig").Renderer;

const Transform = @import("components/transform.zig").Transform;
const SpriteRenderer = @import("components/sprite-renderer.zig").SpriteRenderer;
const Camera2D = @import("components/camera.zig").Camera2D;

const StandardMaterial = @import("materials/standard-material.zig").StandardMaterial;
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
    _ = try go.addComponent(SpriteRenderer("src/assets/textures/logo.png"));

    const transform = go.getComponent(Transform) orelse unreachable;
    transform.scale.setScalar(2);

    const renderer = go.getComponent(SpriteRenderer("")) orelse unreachable;
    var newColor = Vector4.fromXYZW(1, 1, 0, 0.5);
    renderer.setColor(&newColor);

    const go2 = try scene.addGameObject();
    _ = try go2.addComponent(Transform);
    _ = try go2.addComponent(SpriteRenderer("src/assets/textures/circle.png"));

    const renderer2 = go2.getComponent(SpriteRenderer("")) orelse unreachable;
    var newColor2 = Vector4.fromXYZW(1, 1, 0, 1);
    renderer2.setColor(&newColor2);

    const camera = scene.addGameObject() catch unreachable;
    _ = try camera.addComponent(Transform);
    _ = try camera.addComponent(Camera2D);

    scene.makeCameraCurrent(camera);
    //#endregion

    while (true) {
        std.Thread.sleep(1_000_000_000);
    }
}
