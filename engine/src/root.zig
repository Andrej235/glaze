const std = @import("std");
const Debug = @import("debug/debug.zig").Debug;

const WL = @import("platform/linux/wayland.zig").Wayland;
const Renderer = @import("renderer/renderer.zig").Renderer;

const Transform = @import("components/transform.zig").Transform;
const SpriteRenderer = @import("components/sprite-renderer.zig").SpriteRenderer;
const StandardMaterial = @import("utils/standard-material.zig").StandardMaterial;

const App = @import("app.zig").App;

pub fn main() !void {
    const app = try App.create();

    //#region test scene
    const scene = try app.scene_manager.createScene("scene-1");
    const go = try scene.addEntity();
    _ = try go.addComponent(Transform);
    _ = try go.addComponent(SpriteRenderer(StandardMaterial));
    //#endregion

    while (true) {
        Debug.logFps();
        std.Thread.sleep(1_000_000_000);
    }
}
