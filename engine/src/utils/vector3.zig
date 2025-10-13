const Vector2 = @import("vector2.zig").Vector2;

pub const Vector3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) Vector3 {
        return Vector3{
            .x = x,
            .y = y,
            .z = z,
        };
    }

    pub fn fromVec2(vector2: *Vector2) Vector3 {
        return init(vector2.x, vector2.y, 0);
    }

    pub fn fromVec2WithZ(vector2: *Vector2, z: f32) Vector3 {
        return init(vector2.x, vector2.y, z);
    }

    pub fn toVec2(self: *Vector3) Vector2 {
        return Vector2.init(self.x, self.y);
    }

    pub fn setScalar(self: *Vector3, scalar: f32) void {
        self.x = scalar;
        self.y = scalar;
        self.z = scalar;
    }
};
