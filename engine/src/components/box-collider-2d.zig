const std = @import("std");
const Aabb = @import("../vectors/aabb.zig").Aabb;
const Vector2 = @import("../vectors/vector2.zig").Vector2;

const GameObject = @import("../scene-manager/game_object.zig").GameObject;
const Transform = @import("./transform.zig").Transform;

pub const BoxCollider2D = struct {
    game_object: ?*GameObject = null,
    transform: *Transform = undefined,
    scale: f32 = 1.0,

    pub fn create(ptr: *BoxCollider2D) !void {
        ptr.* = BoxCollider2D{};
    }

    pub fn start(self: *BoxCollider2D) !void {
        if (self.game_object.?.getComponent(Transform)) |t| {
            self.transform = t;
        } else {
            return error.TransformNotFound;
        }
    }

    pub fn getAabb(self: *BoxCollider2D) Aabb {
        const cosr = std.math.cos(self.transform.rotation.z);
        const sinr = std.math.sin(self.transform.rotation.z);
        const hx = self.transform.scale.x / 2;
        const hy = self.transform.scale.y / 2;

        const ext_x = @abs(hx * cosr) + @abs(hy * sinr);
        const ext_y = @abs(hx * sinr) + @abs(hy * cosr);

        const min = Vector2.fromXY(self.transform.position.x - ext_x, self.transform.position.y - ext_y);
        const max = Vector2.fromXY(self.transform.position.x + ext_x, self.transform.position.y + ext_y);

        return Aabb.init(min, max);
    }
};
