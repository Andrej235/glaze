const std = @import("std");

const GameObject = @import("../scene-manager/game_object.zig").GameObject;
const Vector3 = @import("../vectors/vector3.zig").Vector3;

pub const Transform = struct {
    game_object: ?*GameObject = null,

    position: Vector3 = Vector3.fromXYZ(0.0, 0.0, 0.0),
    rotation: Vector3 = Vector3.fromXYZ(0.0, 0.0, 0.0),
    scale: Vector3 = Vector3.fromXYZ(1.0, 1.0, 1.0),

    pub fn create(ptr: *Transform) !void {
        ptr.* = Transform{};
    }

    pub fn setPosition(self: *Transform, position: Vector3) void {
        self.position.x = position.x;
        self.position.y = position.y;
        self.position.z = position.z;
    }

    pub fn setRotation(self: *Transform, rotation: Vector3) void {
        self.rotation.x = rotation.x;
        self.rotation.y = rotation.y;
        self.rotation.z = rotation.z;
    }

    pub fn setScale(self: *Transform, scale: Vector3) void {
        self.scale.x = scale.x;
        self.scale.y = scale.y;
        self.scale.z = scale.z;
    }

    pub fn get2DMatrix(self: *const Transform) [16]f32 {
        const cos_r = std.math.cos(self.rotation.z);
        const sin_r = std.math.sin(self.rotation.z);

        return .{
            self.scale.x * cos_r,  self.scale.x * sin_r, 0.0,             0.0,
            -self.scale.y * sin_r, self.scale.y * cos_r, 0.0,             0.0,
            0.0,                   0.0,                  self.scale.z,    0.0,
            self.position.x,       self.position.y,      self.position.z, 1.0,
        };
    }
};
