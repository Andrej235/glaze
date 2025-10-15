const std = @import("std");

const Caster = @import("../utils/caster.zig");
const App = @import("../app.zig").App;

const GameObject = @import("../scene-manager/game_object.zig").GameObject;
const Transform = @import("../components/transform.zig").Transform;
const Rigidbody = @import("../components/rigidbody-2d.zig").Rigidbody2D;
const Collider = @import("../components/box-collider-2d.zig").BoxCollider2D;

const Pair = struct {
    go1: *GameObject,
    go2: *GameObject,

    pub fn init(go1: *GameObject, go2: *GameObject) Pair {
        return Pair{ .go1 = go1, .go2 = go2 };
    }

    pub fn makeKey(self: Pair) u64 {
        // Unwrap this into 1 if? Could remove a few cycles
        const min_id = @min(self.go1.unique_id, self.go1.unique_id);
        const max_id = @max(self.go1.unique_id, self.go1.unique_id);
        return (@as(u64, min_id) << 32) | @as(u64, max_id);
    }
};

pub const PhysicsEngine = struct {
    app: *App,
    handler_id: i64,

    potential_collision_pairs_hash: std.AutoHashMapUnmanaged(u64, *void),

    current_contacts: std.ArrayListUnmanaged(Pair),
    prev_contacts: std.ArrayListUnmanaged(Pair),

    fn fixedUpdate(_: f64, data: ?*anyopaque) !void {
        const self = try Caster.castFromNullableAnyopaque(PhysicsEngine, data);

        const scene = self.app.scene_manager.getActiveScene() catch return;
        const game_objects = scene.getActiveGameObjects() catch return;

        self.potential_collision_pairs_hash.clearRetainingCapacity();
        self.current_contacts.clearRetainingCapacity();

        for (game_objects.items, 0..) |go1, i| {
            for (game_objects.items[i + 1 ..]) |go2| {
                if (go1 == go2) continue;

                var pair = Pair.init(go1, go2);
                const key = pair.makeKey();

                if (!self.potential_collision_pairs_hash.contains(key)) {
                    self.potential_collision_pairs_hash.put(std.heap.c_allocator, key, @ptrCast(@constCast(&null))) catch {};

                    // narrow phase
                    if (checkForCollision(pair.go1, pair.go2)) {
                        self.current_contacts.append(std.heap.c_allocator, pair) catch {};
                    }
                }
            }
        }

        for (self.current_contacts.items) |cur| {
            var found = false;
            for (self.prev_contacts.items) |prev| {
                if (cur.makeKey() == prev.makeKey()) {
                    std.debug.print("Collision stay {}-{}\n", .{ cur.go1.unique_id, cur.go2.unique_id });
                    found = true;
                    break;
                }
            }

            if (!found) {
                std.debug.print("Collision enter {}-{}\n", .{ cur.go1.unique_id, cur.go2.unique_id });
            }
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
                std.debug.print("Collision leave {}-{}\n", .{ prev.go1.unique_id, prev.go2.unique_id });
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

    pub fn init(app: *App) !*PhysicsEngine {
        const physics_engine: *PhysicsEngine = try std.heap.page_allocator.create(PhysicsEngine);
        const handler_id = try app.event_system.getRenderEvents().registerOnFixedUpdate(fixedUpdate, physics_engine);

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
