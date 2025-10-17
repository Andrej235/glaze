const std = @import("std");
const GameObject = @import("../scene-manager/game_object.zig").GameObject;
const Transform = @import("../components/transform.zig").Transform;

const Vector3 = @import("../vectors/vector3.zig").Vector3;

pub const Rigidbody2D = struct {
    game_object: ?*GameObject = null,
    transform: *Transform = undefined,

    velocity: Vector3 = Vector3{ .x = 0, .y = 0, .z = 0 },
    acceleration: Vector3 = Vector3{ .x = 0, .y = 0, .z = 0 },
    force_accumulator: Vector3 = Vector3{ .x = 0, .y = 0, .z = 0 },

    gravity: Vector3 = Vector3{ .x = 0, .y = -9.81, .z = 0 },
    damping: f32 = 0.98, // drag / air resistance

    mass: f32 = 1.0,
    inv_mass: f32 = 1.0,

    restitution: f32 = 0.2, // bounciness

    pub fn create(ptr: *Rigidbody2D) !void {
        ptr.* = Rigidbody2D{};
    }

    pub fn start(self: *Rigidbody2D) !void {
        if (self.game_object.?.getComponent(Transform)) |t| {
            self.transform = t;
        } else {
            return error.TransformNotFound;
        }
    }

    /// Apply a continuous force (accumulated until next integrate).
    pub fn addForce(self: *Rigidbody2D, force: *Vector3) void {
        _ = self.force_accumulator.add(force);
    }

    /// Apply an instantaneous velocity change (collision response, impulses).
    pub fn applyImpulse(self: *Rigidbody2D, impulse: *Vector3) void {
        var scaled = impulse.clone();
        _ = scaled.mulScalar(self.inv_mass);
        _ = self.velocity.add(&scaled);
    }

    /// Apply position correction for penetration resolution.
    pub fn applyPositionCorrection(self: *Rigidbody2D, correction: *Vector3) void {
        // _ = self.velocity.add(correction);
        _ = self.transform.position.add(correction);
    }

    /// Integrate all physics each frame. Uses semi implicit Euler.
    pub fn integrate(self: *Rigidbody2D, dt: f32) void {
        if (self.inv_mass == 0) return; // static body

        // a = F/m
        var force = self.force_accumulator.clone();
        _ = force.add(&self.gravity);

        var accel = force.clone();
        _ = accel.mulScalar(self.inv_mass);

        // v += a * dt
        _ = self.velocity.add(accel.mulScalar(dt));

        // damping
        _ = self.velocity.mulScalar(self.damping);

        // p += v * dt
        var dp = self.velocity.clone();
        _ = dp.mulScalar(dt);
        _ = self.transform.position.add(&dp);

        // clear forces
        _ = self.force_accumulator.setScalar(0);
    }

    pub fn lateUpdate(self: *Rigidbody2D, deltatime: f32) !void {
        self.integrate(deltatime);
    }
};
