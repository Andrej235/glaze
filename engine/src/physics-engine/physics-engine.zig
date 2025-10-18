const std = @import("std");

const Debug = @import("../debug/debug.zig").Debug;

const c_allocator_util = @import("../utils/c_allocator_util.zig");
const cAlloc = c_allocator_util.cAlloc;
const cFree = c_allocator_util.cFree;

const Caster = @import("../utils/caster.zig");
const App = @import("../app.zig").App;

const Transform = @import("../components/transform.zig").Transform;
const Rigidbody = @import("../components/rigidbody-2d.zig").Rigidbody2D;
const GameObject = @import("../scene-manager/game_object.zig").GameObject;
const Collider = @import("../components/box-collider-2d.zig").BoxCollider2D;
const RenderEvents = @import("../event-system/events/render_events.zig").RenderEvents;

const Vector3 = @import("../vectors/vector3.zig").Vector3;
const Vector2 = @import("../vectors/vector2.zig").Vector2;
const Aabb = @import("../vectors//aabb.zig").Aabb;

pub fn PhysicsEngine(comptime ThreadCount: usize) type {
    return struct {
        const Self = @This();

        app: *App,
        render_events: *RenderEvents,

        handler_id: i64, // Id of OnUpdate event
        thread_pool: [ThreadCount]WorkerThread, // Thread pool used for cell cleaning

        fn update(_: f32, data: ?*anyopaque) !void {
            const self = try Caster.castFromNullableAnyopaque(Self, data);

            const scene = self.app.scene_manager.getActiveScene() catch return;
            const spatial_hash = scene.spatial_hash;

            const main_loop_timer = Debug.startTimer("Main loop");
            try spatial_hash.registerGameObjects();

            const chunk_size = spatial_hash.cells.len / self.thread_pool.len;

            inline for (&self.thread_pool, 0..) |*worker, i| {
                const start = i * chunk_size;
                const end = if (i == self.thread_pool.len - 1)
                    spatial_hash.cells.len
                else
                    start + chunk_size;

                worker.assignJob(spatial_hash.cells, start, end);
            }

            self.waitForTAllhreads();

            main_loop_timer.end();
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

        pub fn create(app: *App) !*PhysicsEngineFns {
            const instance: *Self = try cAlloc(Self);

            // Connect main update event
            const handler_id: i64 = try app.event_system.getRenderEvents().registerOnUpdate(update, instance);

            instance.* = Self{
                .app = app,
                .render_events = app.event_system.getRenderEvents(),
                .handler_id = handler_id,
                .thread_pool = undefined,
            };

            // Initialize thread pool
            for (&instance.thread_pool) |*slot| {
                try WorkerThread.initInPlace(slot);
            }

            // Create object that holds physics engine functions
            const physics_engine_fns: *PhysicsEngineFns = try cAlloc(PhysicsEngineFns);
            physics_engine_fns.instance = instance;
            physics_engine_fns.destroy = destroy;
            physics_engine_fns.pause = pause;
            physics_engine_fns.unpause = unpause;

            return physics_engine_fns;
        }

        /// Destroy the physics engine
        ///
        /// ### Errors
        /// - `CasterFailed`: Failed to cast data to physics engine
        pub fn destroy(data: *anyopaque) PhysicsEngineError!void {
            const self = Caster.castFromNullableAnyopaque(Self, data) catch return PhysicsEngineError.CasterFailed;

            self.stopAllThreads();
            cFree(self);
        }

        /// Pause the physics engine
        ///
        /// ### Errors
        /// - `CasterFailed`: Failed to cast data to physics engine
        /// - `FailedToPauseEvents`: Failed to pause events
        pub fn pause(data: *anyopaque) PhysicsEngineError!void {
            const self = Caster.castFromNullableAnyopaque(Self, data) catch return PhysicsEngineError.CasterFailed;

            self.render_events.on_update.pauseHandlerById(self.handler_id) catch return PhysicsEngineError.FailedToPauseEvents;
            self.waitForTAllhreads();
        }

        /// Resume the physics engine
        ///
        /// ### Errors
        /// - `CasterFailed`: Failed to cast data to physics engine
        /// - `FailedToResumeEvents`: Failed to resume events
        pub fn unpause(data: *anyopaque) PhysicsEngineError!void {
            const self = Caster.castFromNullableAnyopaque(Self, data) catch return PhysicsEngineError.CasterFailed;
            self.render_events.on_update.resumeHandlerById(self.handler_id) catch return PhysicsEngineError.FailedToResumeEvents;
        }

        // --------------------------- HELPER FUNCTIONS --------------------------- //
        fn waitForTAllhreads(self: *Self) void {
            for (&self.thread_pool) |*worker| worker.waitDone();
        }

        fn stopAllThreads(self: *Self) void {
            for (&self.thread_pool) |*worker| worker.stop();
        }

        fn checkForCollision(go1: *GameObject, go2: *GameObject) bool {
            const col1 = go1.getComponent(Collider) orelse return false;
            const col2 = go2.getComponent(Collider) orelse return false;

            var aabb1 = col1.getAabb();
            var aabb2 = col2.getAabb();

            return aabb1.intersects(&aabb2);
        }
    };
}

pub const PhysicsEngineFns = struct {
    instance: *anyopaque,
    destroy: *const fn (self: *anyopaque) PhysicsEngineError!void,
    pause: *const fn (self: *anyopaque) PhysicsEngineError!void,
    unpause: *const fn (self: *anyopaque) PhysicsEngineError!void,

    inline fn deinit(self: *PhysicsEngineFns) !void {
        try self.destroy(self.instance);
        cFree(self);
    }
};

const WorkerThread = struct {
    thread: ?std.Thread = null,
    should_stop: bool = false,

    spatial_hash: ?[]std.ArrayList(*GameObject) = null,
    start_index: usize = 0,
    end_index: usize = 0,

    mutex: std.Thread.Mutex = .{},
    cond: std.Thread.Condition = .{},
    has_work: bool = false,
    done: bool = true,

    pub fn initInPlace(slot: *WorkerThread) !void {
        slot.thread = null;
        slot.spatial_hash = null;
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
            self.has_work = false;
            self.mutex.unlock();

            if (self.spatial_hash) |spatial_hash| {
                var start_ptr = spatial_hash.ptr + self.start_index;
                const end_ptr = spatial_hash.ptr + self.end_index;

                while (start_ptr != end_ptr) : (start_ptr += 1) {
                    const current_bucket = &start_ptr[0].items;
                    const count = current_bucket.len;
                    if (count <= 0) continue;

                    const go_ptr = current_bucket.ptr; // pointer to first game object in bucket
                    if (count > 2) {
                        var j: usize = 0;
                        while (j < count) : (j += 1) {
                            const go1 = go_ptr[j];
                            var k = j + 1;
                            while (k < count) : (k += 1) {
                                const go2 = go_ptr[k];
                                _ = go1;
                                _ = go2;
                            }
                        }
                    }

                    // This is the same as clearRetainingCapacity just without any safety checks
                    current_bucket.len = 0;
                }
            }

            self.mutex.lock();
            self.done = true;
            self.cond.broadcast();
            self.mutex.unlock();
        }
    }

    pub fn assignJob(self: *WorkerThread, rows: []std.ArrayList(*GameObject), start_idx: usize, end_idx: usize) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.spatial_hash = rows;
        self.start_index = start_idx;
        self.end_index = end_idx;

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

const PhysicsEngineError = error{
    CasterFailed,
    FailedToPauseEvents,
    FailedToResumeEvents,
};
