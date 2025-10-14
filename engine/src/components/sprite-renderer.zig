const std = @import("std");
const typeId = @import("../utils/type-id.zig").typeId;

const Renderer = @import("../renderer/renderer.zig").Renderer;
const GameObject = @import("../scene-manager/game_object.zig").GameObject;
const Material = @import("../materials/material.zig").Material;
const StandardMaterial = @import("../materials/standard-material.zig").StandardMaterial;
const Vector4 = @import("../vectors/vector4.zig").Vector4;

pub fn SpriteRenderer(comptime spritePath: []const u8) type {
    return struct {
        game_object: ?*GameObject = null,
        material: ?*Material = null,
        sprite_path: []const u8 = spritePath,

        color: *[4]f32,

        const Self = @This();

        pub fn create(ptr: *Self) !void {
            const color = try std.heap.c_allocator.create([4]f32);
            color.* = [4]f32{ 1.0, 1.0, 1.0, 1.0 };

            ptr.* = Self{
                .color = color,
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

        pub fn setColor(self: *Self, color: *Vector4) void {
            self.color.* = color.toArray();
        }

        pub fn getId() u32 {
            return typeId(SpriteRenderer(""));
        }
    };
}
