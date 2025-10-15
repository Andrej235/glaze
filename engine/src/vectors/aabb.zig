const Vector2 = @import("./vector2.zig").Vector2;

pub const Aabb = struct {
    min: Vector2,
    max: Vector2,

    pub fn init(min: Vector2, max: Vector2) Aabb {
        return Aabb{
            .min = min,
            .max = max,
        };
    }

    pub fn intersects(self: *Aabb, other: *Aabb) bool {
        return !(self.max.x < other.min.x or
            self.min.x > other.max.x or
            self.max.y < other.min.y or
            self.min.y > other.max.y);
    }
};
