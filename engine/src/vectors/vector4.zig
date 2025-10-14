const Vector2 = @import("vector2.zig").Vector2;
const Vector3 = @import("vector3.zig").Vector3;

pub const Vector4 = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub fn fromScalar(scalar: f32) Vector4 {
        return fromXYZW(scalar, scalar, scalar, scalar);
    }

    pub fn fromXYZW(x: f32, y: f32, z: f32, w: f32) Vector4 {
        return Vector4{
            .x = x,
            .y = y,
            .z = z,
            .w = w,
        };
    }

    pub fn fromVec2(vector2: *Vector2) Vector4 {
        return fromXYZW(vector2.x, vector2.y, 0, 0);
    }

    pub fn fromVec2WithZW(vector2: *Vector2, z: f32, w: f32) Vector4 {
        return fromXYZW(vector2.x, vector2.y, z, w);
    }

    pub fn fromVec3(vector3: *Vector3) Vector4 {
        return fromXYZW(vector3.x, vector3.y, vector3.z, 0);
    }

    pub fn fromVec3WithW(vector3: *Vector3, w: f32) Vector4 {
        return fromXYZW(vector3.x, vector3.y, vector3.z, w);
    }

    pub fn toVec2(self: *Vector4) Vector2 {
        return Vector2.fromXY(self.x, self.y);
    }

    pub fn toVec3(self: *Vector4) Vector3 {
        return Vector3.fromXYZ(self.x, self.y, self.z);
    }

    pub fn toArray(self: *Vector4) [4]f32 {
        return [4]f32{ self.x, self.y, self.z, self.w };
    }

    pub fn setScalar(self: *Vector4, scalar: f32) void {
        self.x = scalar;
        self.y = scalar;
        self.z = scalar;
        self.w = scalar;
    }
};
