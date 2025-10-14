const std = @import("std");
const typeId = @import("../utils/type-id.zig").typeId;

const Renderer = @import("../renderer/renderer.zig").Renderer;
const GameObject = @import("../scene-manager/game_object.zig").GameObject;
const Material = @import("../materials/material.zig").Material;
const StandardMaterial = @import("../materials/standard-material.zig").StandardMaterial;

pub fn SpriteRenderer(comptime spritePath: []const u8) type {
    return struct {
        game_object: ?*GameObject = null,
        material: ?*Material,
        sprite_path: []const u8 = spritePath,

        const Self = @This();

        pub fn create(ptr: *Self) !void {
            ptr.* = Self{
                .material = null,
            };
        }

        pub fn getMaterial(self: *Self) !*Material {
            if (self.material == null) {
                const cache = try Renderer.cacheMaterial(StandardMaterial);
                self.material = cache.material;
            }

            return self.material.?;
        }

        pub fn getSpriteTexture(self: *Self) ?u32 {
            return Renderer.cacheTexture(self.sprite_path) catch null;
        }

        pub fn getId() u32 {
            return typeId(SpriteRenderer(""));
        }
    };
}
