const Renderer = @import("../renderer/renderer.zig").Renderer;
const GameObject = @import("../scene-manager/game_object.zig").GameObject;
const StandardMaterial = @import("../utils/standard-material.zig").StandardMaterial;

pub fn SpriteRenderer(comptime TMaterial: type) type {
    return struct {
        game_object: ?*GameObject = null,
        material: ?*TMaterial,

        const Self = @This();

        pub fn create(ptr: *Self) !void {
            ptr.* = Self{
                .material = null,
            };
        }

        pub fn getMaterial(self: Self) !*TMaterial {
            if (self.material == null)
                self.material = try Renderer.cacheMaterial(TMaterial);
                
            return self.material;
        }
    };
}
