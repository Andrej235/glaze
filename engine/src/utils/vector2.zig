const Vector3 = @import("./vector3.zig").Vector3;

pub const Vector2 = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) Vector2 {
        return Vector2{
            .x = x,
            .y = y,
        };
    }

    pub fn toVec3(self: *Vector2) Vector3 {
        return Vector3.fromVec2(self);
    }

    pub fn toVec3WithZ(self: *Vector2, z: f32) Vector3 {
        return Vector3.fromVec2WithZ(self, z);
    }

    pub fn fromVec3(vector3: Vector3) Vector2 {
        return init(vector3.x, vector3.y);
    }
};
