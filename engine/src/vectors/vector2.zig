const Vector3 = @import("./vector3.zig").Vector3;
const Vector4 = @import("./vector4.zig").Vector4;

pub const Vector2 = struct {
    x: f32,
    y: f32,

    pub fn fromScalar(scalar: f32) Vector2 {
        return fromXY(scalar, scalar);
    }

    pub fn fromXY(x: f32, y: f32) Vector2 {
        return Vector2{
            .x = x,
            .y = y,
        };
    }

    pub fn fromVec3(vector3: *Vector3) Vector2 {
        return fromXY(vector3.x, vector3.y);
    }

    pub fn fromVec4(vector4: *Vector4) Vector2 {
        return fromXY(vector4.x, vector4.y);
    }

    pub fn toVec3(self: *Vector2) Vector3 {
        return Vector3.fromVec2(self);
    }

    pub fn toVec3WithZ(self: *Vector2, z: f32) Vector3 {
        return Vector3.fromVec2WithZ(self, z);
    }

    pub fn toVec4(self: *Vector2) Vector4 {
        return Vector4.fromVec2(self);
    }

    pub fn toVec4WithZW(self: *Vector2, z: f32, w: f32) Vector4 {
        return Vector4.fromVec2WithZW(self, z, w);
    }

    pub fn toArray(self: *Vector2) [2]f32 {
        return [2]f32{ self.x, self.y };
    }

    pub fn setScalar(self: *Vector2, scalar: f32) void {
        self.x = scalar;
        self.y = scalar;
    }
};
