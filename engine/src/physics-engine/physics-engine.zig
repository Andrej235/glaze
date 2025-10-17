const std = @import("std");

const Caster = @import("../utils/caster.zig");
const App = @import("../app.zig").App;

const GameObject = @import("../scene-manager/game_object.zig").GameObject;
const Transform = @import("../components/transform.zig").Transform;
const Rigidbody = @import("../components/rigidbody-2d.zig").Rigidbody2D;
const Collider = @import("../components/box-collider-2d.zig").BoxCollider2D;

const Vector3 = @import("../vectors/vector3.zig").Vector3;
const Vector2 = @import("../vectors/vector2.zig").Vector2;
const Aabb = @import("../vectors//aabb.zig").Aabb;

const Pair = struct {
    go1: *GameObject,
    go2: *GameObject,

    pub fn init(go1: *GameObject, go2: *GameObject) Pair {
        return Pair{ .go1 = go1, .go2 = go2 };
    }

    pub fn makeKey(self: Pair) u64 {
        // Unwrap this into 1 if? Could remove a few cycles
        const min_id = @min(self.go1.unique_id, self.go1.unique_id);
        const max_id = @max(self.go2.unique_id, self.go2.unique_id);
        return (@as(u64, min_id) << 32) | @as(u64, max_id);
    }
};

pub const PhysicsEngine = struct {
    app: *App,
    handler_id: i64,

    potential_collision_pairs_hash: std.AutoHashMapUnmanaged(u64, *void),

    current_contacts: std.ArrayListUnmanaged(Pair),
    prev_contacts: std.ArrayListUnmanaged(Pair),

    fn update(_: f32, data: ?*anyopaque) !void {
        const self = try Caster.castFromNullableAnyopaque(PhysicsEngine, data);

        const scene = self.app.scene_manager.getActiveScene() catch return;
        const hash = scene.spatial_hash;

        self.potential_collision_pairs_hash.clearRetainingCapacity();
        self.current_contacts.clearRetainingCapacity();

        for (hash.cells) |bucket_row| {
            for (bucket_row) |bucket| {
                const game_objects = bucket.items;
                if (game_objects.len < 2) continue;
                std.debug.print("{}\n", .{game_objects.len});

                for (game_objects, 0..) |go1, i| {
                    for (game_objects[i + 1 ..]) |go2| {
                        var pair = Pair.init(go1, go2);
                        const key = pair.makeKey();

                        if (!self.potential_collision_pairs_hash.contains(key)) {
                            self.potential_collision_pairs_hash.put(std.heap.c_allocator, key, @ptrCast(@constCast(&null))) catch {
                                std.debug.print("error 1\n", .{});
                                continue;
                            };

                            // narrow phase
                            if (checkForCollision(pair.go1, pair.go2)) {
                                self.current_contacts.append(std.heap.c_allocator, pair) catch {
                                    std.debug.print("error 2\n", .{});
                                    continue;
                                };
                            }
                        }
                    }
                }
            }
        }

        hash.clear();

        for (self.current_contacts.items) |cur| {
            var found = false;
            for (self.prev_contacts.items) |prev| {
                if (cur.makeKey() == prev.makeKey()) {
                    // std.debug.print("Collision stay {}-{}\n", .{ cur.go1.unique_id, cur.go2.unique_id });
                    found = true;
                    break;
                }
            }

            if (!found) {
                // std.debug.print("Collision enter {}-{}\n", .{ cur.go1.unique_id, cur.go2.unique_id });
            }

            // physics
            const rb1 = cur.go1.getComponent(Rigidbody);
            const rb2 = cur.go2.getComponent(Rigidbody);

            if (rb1 == null and rb2 == null) continue;

            const tr1 = cur.go1.getComponent(Transform) orelse continue;
            const tr2 = cur.go2.getComponent(Transform) orelse continue;

            resolveAabbPenetration(tr1, tr2, rb1, rb2);
        }

        for (self.prev_contacts.items) |prev| {
            var stillExists = false;
            for (self.current_contacts.items) |cur| {
                if (cur.makeKey() == prev.makeKey()) {
                    stillExists = true;
                    break;
                }
            }

            if (!stillExists) {
                // Handle collision end
                // std.debug.print("Collision leave {}-{}\n", .{ prev.go1.unique_id, prev.go2.unique_id });
            }
        }

        // Swap current and previous contacts for the next frame
        const temp = self.prev_contacts;
        self.prev_contacts = self.current_contacts;
        self.current_contacts = temp;
    }

    fn checkForCollision(go1: *GameObject, go2: *GameObject) bool {
        const col1 = go1.getComponent(Collider) orelse return false;
        const col2 = go2.getComponent(Collider) orelse return false;

        var aabb1 = col1.getAabb();
        var aabb2 = col2.getAabb();

        return aabb1.intersects(&aabb2);
    }

    pub fn resolveAabbPenetration(transform_a: *Transform, transform_b: *Transform, rigidbody_a: ?*Rigidbody, rigidbody_b: ?*Rigidbody) void {
        const dx = transform_b.position.x - transform_a.position.x;
        const dy = transform_b.position.y - transform_a.position.y;

        const half_a_x = transform_a.scale.x * 0.5;
        const half_a_y = transform_a.scale.y * 0.5;
        const half_b_x = transform_b.scale.x * 0.5;
        const half_b_y = transform_b.scale.y * 0.5;

        const overlap_x = half_a_x + half_b_x - @abs(dx);
        const overlap_y = half_a_y + half_b_y - @abs(dy);

        if (overlap_x <= 0 or overlap_y <= 0) return; // no collision

        var mtv = Vector3.zero();
        if (overlap_x > overlap_y) {
            mtv.y = if (dy < 0) -overlap_y * 0.5 else overlap_y * 0.5;
        } else {
            mtv.x = if (dx < 0) -overlap_x * 0.5 else overlap_x * 0.5;
        }

        if (rigidbody_a) |r| {
            var cor = if (rigidbody_b == null) mtv else mtv.clone();
            r.applyPositionCorrection(cor.mulScalar(-1));
        }

        if (rigidbody_b) |r| {
            r.applyPositionCorrection(&mtv);
        }
    }

    pub fn init(app: *App) !*PhysicsEngine {
        const physics_engine: *PhysicsEngine = try std.heap.page_allocator.create(PhysicsEngine);
        const handler_id = try app.event_system.getRenderEvents().registerOnUpdate(update, physics_engine);

        physics_engine.* = PhysicsEngine{
            .app = app,
            .handler_id = handler_id,
            .potential_collision_pairs_hash = std.AutoHashMapUnmanaged(u64, *void){},
            .current_contacts = std.ArrayListUnmanaged(Pair){},
            .prev_contacts = std.ArrayListUnmanaged(Pair){},
        };

        return physics_engine;
    }
};
