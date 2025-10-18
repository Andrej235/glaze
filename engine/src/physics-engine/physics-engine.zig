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

    allocator: std.mem.Allocator,
    thread_pool: [6]WorkerThread, // Thread pool used for cell cleaning

    fn update(_: f32, data: ?*anyopaque) !void {
        const self = try Caster.castFromNullableAnyopaque(PhysicsEngine, data);

        const scene = self.app.scene_manager.getActiveScene() catch return;
        const spatial_hash = scene.spatial_hash;

        for (scene.active_game_objects.items) |item| {
            try spatial_hash.registerObject(item);
        }

        const before = std.time.nanoTimestamp();

        const chunk_size = spatial_hash.cells.len / self.thread_pool.len;

        for (&self.thread_pool, 0..) |*worker, i| {
            const start = i * chunk_size;
            const end = if (i == self.thread_pool.len - 1)
                spatial_hash.cells.len
            else
                start + chunk_size;

            worker.assignJob(spatial_hash.cells[start..end]);
        }

        for (&self.thread_pool) |*worker| worker.waitDone();

        const after = std.time.nanoTimestamp();
        std.log.info("time: {}", .{after - before});
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
        const allocator = std.heap.c_allocator;

        const physics_engine: *PhysicsEngine = try std.heap.page_allocator.create(PhysicsEngine);
        const handler_id = try app.event_system.getRenderEvents().registerOnUpdate(update, physics_engine);

        physics_engine.* = PhysicsEngine{
            .app = app,
            .handler_id = handler_id,
            .allocator = allocator,
            .thread_pool = undefined,
        };

        // Initialize thread pool
        for (&physics_engine.thread_pool) |*slot| {
            try WorkerThread.initInPlace(slot);
        }

        return physics_engine;
    }
};

const WorkerThread = struct {
    thread: ?std.Thread = null,
    rows: ?[]std.ArrayList(*GameObject) = null,
    should_stop: bool = false,

    mutex: std.Thread.Mutex = .{},
    cond: std.Thread.Condition = .{},
    has_work: bool = false,
    done: bool = true,

    pub fn initInPlace(slot: *WorkerThread) !void {
        slot.thread = null;
        slot.rows = null;
        slot.should_stop = false;
        slot.mutex = std.Thread.Mutex{};
        slot.cond = std.Thread.Condition{};
        slot.has_work = false;
        slot.done = true;
        slot.thread = try std.Thread.spawn(.{}, run, .{slot});
    }

    fn run(self: *WorkerThread) void {
        while (true) {
            // Efficiently wait for work or stop signal
            self.mutex.lock();
            while (!self.has_work and !self.should_stop) {
                self.cond.wait(&self.mutex);
            }

            // If we should stop, unlock and return
            if (self.should_stop) {
                self.mutex.unlock();
                return;
            }

            // Process work
            const job = self.rows;
            self.has_work = false;
            self.mutex.unlock();

            if (job) |rows| {
                const cell = rows.ptr;
                for (0..rows.len) |i| {
                    const curr = @as(*std.ArrayList(*GameObject), @ptrFromInt(@intFromPtr(cell + i)));

                    if (curr.items.len == 0) continue;

                    if (curr.items.len > 2) {
                        for (curr.items, 0..) |go1, j| {
                            for (curr.items[j + 1 ..]) |go2| {
                                _ = go1;
                                _ = go2;
                            }
                        }
                    }
                    curr.clearRetainingCapacity();
                }
            }

            self.mutex.lock();
            self.done = true;
            self.cond.broadcast();
            self.mutex.unlock();
        }
    }

    pub fn assignJob(self: *WorkerThread, rows: []std.ArrayList(*GameObject)) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.rows = rows;
        self.has_work = true;
        self.done = false;
        self.cond.signal();
    }

    pub fn waitDone(self: *WorkerThread) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (!self.done) {
            self.cond.wait(&self.mutex);
        }
    }

    pub fn stop(self: *WorkerThread) void {
        self.mutex.lock();
        self.should_stop = true;
        self.cond.signal();
        self.mutex.unlock();

        if (self.thread) |t| t.join();
        self.thread = null;
    }
};
