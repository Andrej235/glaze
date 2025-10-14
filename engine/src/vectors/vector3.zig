const Vector2 = @import("vector2.zig").Vector2;
const Vector4 = @import("vector4.zig").Vector4;

pub const Vector3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn fromScalar(scalar: f32) Vector3 {
        return fromXYZ(scalar, scalar, scalar);
    }

    pub fn fromXYZ(x: f32, y: f32, z: f32) Vector3 {
        return Vector3{
            .x = x,
            .y = y,
            .z = z,
        };
    }

    pub fn fromVec2(vector2: *Vector2) Vector3 {
        return fromXYZ(vector2.x, vector2.y, 0);
    }

    pub fn fromVec2WithZ(vector2: *Vector2, z: f32) Vector3 {
        return fromXYZ(vector2.x, vector2.y, z);
    }

    pub fn fromVec4(vector4: *Vector4) Vector3 {
        return fromXYZ(vector4.x, vector4.y, vector4.z);
    }

    pub fn toVec2(self: *Vector3) Vector2 {
        return Vector2.fromXY(self.x, self.y);
    }

    pub fn toVec4(self: *Vector3) Vector4 {
        return Vector4.fromXYZW(self.x, self.y, self.z, 0);
    }

    pub fn toVec4WithW(self: *Vector3, w: f32) Vector4 {
        return Vector4.fromXYZW(self.x, self.y, self.z, w);
    }

    pub fn toArray(self: *Vector3) [3]f32 {
        return [3]f32{ self.x, self.y, self.z };
    }

    pub fn setScalar(self: *Vector3, scalar: f32) void {
        self.x = scalar;
        self.y = scalar;
        self.z = scalar;
    }
};
