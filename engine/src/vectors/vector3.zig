const std = @import("std");
const Vector2 = @import("vector2.zig").Vector2;
const Vector4 = @import("vector4.zig").Vector4;

pub const Vector3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub inline fn zero() Vector3 {
        return Vector3{
            .x = 0,
            .y = 0,
            .z = 0,
        };
    }

    pub inline fn fromScalar(scalar: f32) Vector3 {
        return fromXYZ(scalar, scalar, scalar);
    }

    pub inline fn fromXYZ(x: f32, y: f32, z: f32) Vector3 {
        return Vector3{
            .x = x,
            .y = y,
            .z = z,
        };
    }

    pub inline fn fromVec2(vector2: *Vector2) Vector3 {
        return fromXYZ(vector2.x, vector2.y, 0);
    }

    pub inline fn fromVec2WithZ(vector2: *Vector2, z: f32) Vector3 {
        return fromXYZ(vector2.x, vector2.y, z);
    }

    pub inline fn fromVec4(vector4: *Vector4) Vector3 {
        return fromXYZ(vector4.x, vector4.y, vector4.z);
    }

    pub inline fn toVec2(self: *Vector3) Vector2 {
        return Vector2.fromXY(self.x, self.y);
    }

    pub inline fn toVec4(self: *Vector3) Vector4 {
        return Vector4.fromXYZW(self.x, self.y, self.z, 0);
    }

    pub inline fn toVec4WithW(self: *Vector3, w: f32) Vector4 {
        return Vector4.fromXYZW(self.x, self.y, self.z, w);
    }

    pub inline fn toArray(self: *Vector3) [3]f32 {
        return [3]f32{ self.x, self.y, self.z };
    }

    pub inline fn clone(self: *Vector3) Vector3 {
        return Vector3{
            .x = self.x,
            .y = self.y,
            .z = self.z,
        };
    }

    pub inline fn setScalar(self: *Vector3, scalar: f32) *Vector3 {
        self.x = scalar;
        self.y = scalar;
        self.z = scalar;
        return self;
    }

    pub inline fn setXYZ(self: *Vector3, x: f32, y: f32, z: f32) *Vector3 {
        self.x = x;
        self.y = y;
        self.z = z;
        return self;
    }

    pub inline fn add(self: *Vector3, vector3: *Vector3) *Vector3 {
        self.x += vector3.x;
        self.y += vector3.y;
        self.z += vector3.z;
        return self;
    }

    pub inline fn addScalar(self: *Vector3, scalar: f32) *Vector3 {
        self.x += scalar;
        self.y += scalar;
        self.z += scalar;
        return self;
    }

    pub inline fn sub(self: *Vector3, vector3: *Vector3) *Vector3 {
        self.x -= vector3.x;
        self.y -= vector3.y;
        self.z -= vector3.z;
        return self;
    }

    pub inline fn subScalar(self: *Vector3, scalar: f32) *Vector3 {
        self.x -= scalar;
        self.y -= scalar;
        self.z -= scalar;
        return self;
    }

    pub inline fn mul(self: *Vector3, vector3: *Vector3) *Vector3 {
        self.x *= vector3.x;
        self.y *= vector3.y;
        self.z *= vector3.z;
        return self;
    }

    pub inline fn mulScalar(self: *Vector3, scalar: f32) *Vector3 {
        self.x *= scalar;
        self.y *= scalar;
        self.z *= scalar;
        return self;
    }

    pub inline fn div(self: *Vector3, vector3: *Vector3) *Vector3 {
        self.x /= vector3.x;
        self.y /= vector3.y;
        self.z /= vector3.z;
        return self;
    }

    pub inline fn divScalar(self: *Vector3, scalar: f32) *Vector3 {
        const inv = 1.0 / scalar;
        self.x *= inv;
        self.y *= inv;
        self.z *= inv;
        return self;
    }

    pub inline fn normalize(self: *Vector3) *Vector3 {
        const len = self.length();
        const inverse = 1.0 / if (len == 0) 1.0 else len;

        self.x *= inverse;
        self.y *= inverse;
        self.z *= inverse;
        return self;
    }

    pub inline fn eql(self: Vector3, vector3: Vector3) bool {
        return self.x == vector3.x and self.y == vector3.y and self.z == vector3.z;
    }

    pub inline fn length(self: Vector3) f32 {
        return std.math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub inline fn lengthSquared(self: Vector3) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub inline fn dot(self: Vector3, vector3: Vector3) f32 {
        return self.x * vector3.x + self.y * vector3.y + self.z * vector3.z;
    }
};
