const Renderer = @import("../renderer/renderer.zig").Renderer;
const GameObject = @import("../scene-manager/game_object.zig").GameObject;
const Material = @import("../utils/material.zig").Material;
const StandardMaterial = @import("../utils/standard-material.zig").StandardMaterial;
const typeId = @import("../utils/type-id.zig").typeId;

pub const SpriteRenderer = struct {
    game_object: ?*GameObject = null,
    material: ?*Material,

    pub fn create(ptr: *SpriteRenderer) !void {
        ptr.* = SpriteRenderer{
            .material = null,
        };
    }

    pub fn getMaterial(self: *SpriteRenderer) !*Material {
        if (self.material == null) {
            const cache = try Renderer.cacheMaterial(StandardMaterial);
            self.material = cache.material;
        }

        return self.material.?;
    }
};
