const std = @import("std");
const ArrayList = std.ArrayList;

const App = @import("../app.zig").App;
const Collider = @import("../components/box-collider-2d.zig").BoxCollider2D;
const Rigidbody = @import("../components/rigidbody-2d.zig").Rigidbody2D;
const Transform = @import("../components/transform.zig").Transform;
const Debug = @import("../debug/debug.zig").Debug;
const RenderEvents = @import("../event-system/events/render_events.zig").RenderEvents;
const GameObject = @import("../scene-manager/game_object.zig").GameObject;
const Scene = @import("../scene-manager/scene.zig").Scene;
const SpatialHash = @import("../scene-manager/spatial_hash.zig").SpatialHash;
const c_allocator_util = @import("../utils/c_allocator_util.zig");
const cAlloc = c_allocator_util.cAlloc;
const cFree = c_allocator_util.cFree;
const Caster = @import("../utils/caster.zig");
const Aabb = @import("../vectors//aabb.zig").Aabb;
const Vector2 = @import("../vectors/vector2.zig").Vector2;
const Vector3 = @import("../vectors/vector3.zig").Vector3;

pub fn PhysicsEngine(
    comptime thread_count: usize,
    comptime TSpatialHashBitMapItemType: type,
    comptime spatial_hash_width: u16,
    comptime spatial_hash_height: u16,
    comptime spatial_hash_cell_size: u8,
) type {
    if (@typeInfo(TSpatialHashBitMapItemType).int.signedness != .unsigned)
        @compileError("TSpatialHashBitMapItemType must be an unsigned integer type");

    const grid_width = spatial_hash_width / spatial_hash_cell_size;
    const grid_height = spatial_hash_height / spatial_hash_cell_size;
    const cell_count = @as(u32, grid_width) * grid_height;

    const bit_item_size: u32 = comptime @bitSizeOf(TSpatialHashBitMapItemType);
    const bit_set_size = cell_count / bit_item_size;

    return struct {
        const Self = @This();

        scene: *Scene,
        render_events: *RenderEvents,

        update_event_handler_id: i64,
        thread_pool: [thread_count]WorkerThread(cell_count, bit_set_size, bit_item_size), // used for parallelizing the main loop

        spatial_hash_cells: *[cell_count]std.ArrayList(*GameObject),
        spatial_hash_active_cells_bit_set: *[bit_set_size]u64,

        combined_pairs: *ArrayList(Pair), // TODO: Clean this up in destroy()

        pub fn create(
            app: *App,
            scene: *Scene,
            spatial_hash: *SpatialHash(TSpatialHashBitMapItemType, spatial_hash_width, spatial_hash_height, spatial_hash_cell_size),
        ) !*PhysicsEngineFns {
            // TODO: Handle memory leaks in case that creation fails

            const instance: *Self = try cAlloc(Self);

            const combined_pairs: *ArrayList(Pair) = try cAlloc(ArrayList(Pair));
            combined_pairs.* = try ArrayList(Pair).initCapacity(std.heap.c_allocator, 200);

            // Connect main update event
            const handler_id: i64 = try app.event_system.getRenderEvents().registerOnUpdate(update, instance);

            instance.* = Self{
                .scene = scene,
                .render_events = app.event_system.getRenderEvents(),
                .update_event_handler_id = handler_id,
                .thread_pool = undefined,
                .spatial_hash_cells = spatial_hash.cells,
                .spatial_hash_active_cells_bit_set = spatial_hash.active_cells_bit_set,
                .combined_pairs = combined_pairs,
            };

            // Initialize thread pool
            inline for (&instance.thread_pool) |*slot| {
                try WorkerThread(cell_count, bit_set_size, bit_item_size).initInPlace(slot);
            }

            // Create object that holds physics engine functions
            const physics_engine_fns: *PhysicsEngineFns = try cAlloc(PhysicsEngineFns);
            physics_engine_fns.instance = instance;
            physics_engine_fns.destroy = destroy;
            physics_engine_fns.pause = pause;
            physics_engine_fns.unpause = unpause;

            return physics_engine_fns;
        }

        fn update(_: f32, data: ?*anyopaque) !void {
            //const main_loop_timer = Debug.startTimer("Main loop");
            const self = try Caster.castFromNullableAnyopaque(Self, data);

            const fns = self.scene.spatial_hash_fns;
            try fns.registerGameObjects(fns.instance);

            const cells = self.spatial_hash_cells;
            const active_cells_bit_set = self.spatial_hash_active_cells_bit_set;
            const chunk_size = comptime bit_set_size / thread_count;

            inline for (&self.thread_pool, 0..) |*worker, i| {
                const start = comptime i * chunk_size;
                const end = comptime @min(start + chunk_size, bit_set_size);

                worker.assignJob(cells, active_cells_bit_set, start, end);
            }

            self.waitForTAllhreads();

            // Get size of pairs across all workers
            var total_pairs: usize = 0;
            for (&self.thread_pool) |*worker| {
                total_pairs += worker.work_result.?.items.len;
            }

            // Create array that holds all pairs
            const allocator = std.heap.c_allocator;
            for (&self.thread_pool) |*worker| {
                self.combined_pairs.appendSlice(allocator, worker.work_result.?.items) catch {};
            }

            // Itterate over pairs and resolve collisions
            const ptr = self.combined_pairs.items.ptr;
            const len = self.combined_pairs.items.len;

            for (0..5) |_| {
                for (0..len) |i| {
                    const pair = &ptr[i];

                    var aabb1 = pair.col1.?.getAabb();
                    var aabb2 = pair.col2.?.getAabb();

                    if (!aabb1.intersects(&aabb2)) continue;

                    // If neither has rigidbody, nothing can move → skip
                    if (pair.rb1 == null and pair.rb2 == null) continue;

                    // Resolve collision by moving the rigidbodies only
                    resolveAabbPenetrationStandalone(pair.tr1.?, pair.tr2.?, pair.rb1, pair.rb2);
                }
            }

            self.combined_pairs.items.len = 0;

            //main_loop_timer.end();
        }

        fn resolveAabbPenetrationStandalone(transform_a: *Transform, transform_b: *Transform, rigidbody_a: ?*Rigidbody, rigidbody_b: ?*Rigidbody) void {
            const dx = transform_b.position.x - transform_a.position.x;
            const dy = transform_b.position.y - transform_a.position.y;

            const half_a_x = transform_a.scale.x * 0.5;
            const half_a_y = transform_a.scale.y * 0.5;
            const half_b_x = transform_b.scale.x * 0.5;
            const half_b_y = transform_b.scale.y * 0.5;

            const overlap_x = half_a_x + half_b_x - @abs(dx);
            const overlap_y = half_a_y + half_b_y - @abs(dy);

            if (overlap_x <= 0 or overlap_y <= 0) return;

            // Minimum Translation Vector (MTV)
            var mtv = Vector3.zero();
            if (overlap_x < overlap_y) {
                // Resolve along X
                mtv.x = if (dx < 0) -overlap_x else overlap_x;
            } else {
                // Resolve along Y
                mtv.y = if (dy < 0) -overlap_y else overlap_y;
            }

            const has_a = rigidbody_a != null;
            const has_b = rigidbody_b != null;

            // Apply MTV correctly depending on who can move
            if (has_a and has_b) {
                // both movable -> split the correction
                var mtv_clone = mtv.clone();
                var half = mtv_clone.mulScalar(0.5);
                var half_clone = half.clone();
                rigidbody_a.?.applyPositionCorrection(half_clone.mulScalar(-1));
                rigidbody_b.?.applyPositionCorrection(half);
            } else if (has_a) {
                // only A moves -> move full correction away from B
                var mtv_clone = mtv.clone();
                rigidbody_a.?.applyPositionCorrection(mtv_clone.mulScalar(-1));
            } else if (has_b) {
                // only B moves -> move full correction away from A
                rigidbody_b.?.applyPositionCorrection(&mtv);
            }
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

            self.render_events.on_update.pauseHandlerById(self.update_event_handler_id) catch return PhysicsEngineError.FailedToPauseEvents;
            self.waitForTAllhreads();
        }

        /// Resume the physics engine
        ///
        /// ### Errors
        /// - `CasterFailed`: Failed to cast data to physics engine
        /// - `FailedToResumeEvents`: Failed to resume events
        pub fn unpause(data: *anyopaque) PhysicsEngineError!void {
            const self = Caster.castFromNullableAnyopaque(Self, data) catch return PhysicsEngineError.CasterFailed;
            self.render_events.on_update.resumeHandlerById(self.update_event_handler_id) catch return PhysicsEngineError.FailedToResumeEvents;
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

fn WorkerThread(comptime cell_count: u32, comptime bit_set_size: u32, comptime bit_item_size: u32) type {
    return struct {
        const Self = @This();

        thread: ?std.Thread = null,
        should_stop: bool = false,

        spatial_hash: ?*[cell_count]std.ArrayList(*GameObject) = null,
        active_cells_bit_set: ?*[bit_set_size]u64 = null,

        start_index: usize = 0,
        end_index: usize = 0,

        mutex: std.Thread.Mutex = .{},
        cond: std.Thread.Condition = .{},
        has_work: bool = false,
        done: bool = true,

        work_result: ?*ArrayList(Pair) = null,

        pub fn initInPlace(slot: *Self) !void {
            slot.thread = null;
            slot.spatial_hash = null;
            slot.should_stop = false;
            slot.mutex = std.Thread.Mutex{};
            slot.cond = std.Thread.Condition{};
            slot.has_work = false;
            slot.done = true;
            slot.thread = try std.Thread.spawn(.{}, run, .{slot});

            slot.work_result = try cAlloc(ArrayList(Pair));
            slot.work_result.?.* = ArrayList(Pair){};
            try slot.work_result.?.ensureTotalCapacity(std.heap.c_allocator, 20);
        }

        pub fn assignJob(
            self: *Self,
            cells: *[cell_count]std.ArrayList(*GameObject),
            active_cells_bit_set: *[bit_set_size]u64,
            start_idx: usize,
            end_idx: usize,
        ) void {
            self.mutex.lock();
            defer self.mutex.unlock();

            self.spatial_hash = cells;
            self.active_cells_bit_set = active_cells_bit_set;
            self.start_index = start_idx;
            self.end_index = end_idx;

            self.has_work = true;
            self.done = false;
            self.cond.signal();
        }

        pub fn waitDone(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();

            while (!self.done) {
                self.cond.wait(&self.mutex);
            }
        }

        pub fn stop(self: *Self) void {
            self.mutex.lock();
            self.should_stop = true;
            self.cond.signal();
            self.mutex.unlock();

            if (self.thread) |t| t.join();
            self.thread = null;
        }

        pub fn getNumberOfPairs(self: *Self) usize {
            if (self.work_result) |res| {
                return res.items.len;
            } else return 0;
        }

        fn run(self: *Self) void {
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
                    if (self.active_cells_bit_set) |bit_set| {
                        const allocator = std.heap.c_allocator;
                        self.work_result.?.items.len = 0;

                        var i: usize = self.start_index;
                        while (i < self.end_index) : (i += 1) {
                            var current_64_bits = bit_set[i];
                            if (current_64_bits == 0) continue;
                            bit_set[i] = 0;

                            const current_byte_index = i * bit_item_size;
                            while (current_64_bits != 0) : (current_64_bits &= current_64_bits - 1) {
                                const current_bit_inside_byte: u64 = @ctz(current_64_bits);
                                const current_bucket = &spatial_hash[current_byte_index + current_bit_inside_byte];
                                const count = current_bucket.items.len;
                                current_bucket.clearRetainingCapacity();

                                if (count < 2) continue;

                                const go_ptr = current_bucket.items.ptr; // pointer to first game object in bucket
                                var j: usize = 0;

                                while (j < count) : (j += 1) {
                                    const go1 = go_ptr[j];
                                    var k = j + 1;
                                    while (k < count) : (k += 1) {
                                        const go2 = go_ptr[k];

                                        var pair = Pair.init(go1, go2);

                                        const col1 = pair.go1.getComponent(Collider) orelse continue;
                                        const col2 = pair.go2.getComponent(Collider) orelse continue;

                                        // Remove pairs that dont have transforms
                                        const t1 = pair.go1.getComponent(Transform) orelse continue;
                                        const t2 = pair.go2.getComponent(Transform) orelse continue;

                                        // Remove pairs that dont have rigidbodies
                                        const rb1 = pair.go1.getComponent(Rigidbody);
                                        const rb2 = pair.go2.getComponent(Rigidbody);

                                        pair.col1 = col1;
                                        pair.col2 = col2;

                                        pair.tr1 = t1;
                                        pair.tr2 = t2;

                                        pair.rb1 = rb1;
                                        pair.rb2 = rb2;

                                        self.work_result.?.append(allocator, pair) catch continue;
                                    }
                                }
                            }
                        }
                    }
                }

                self.mutex.lock();
                self.done = true;
                self.cond.broadcast();
                self.mutex.unlock();
            }
        }
    };
}

const Pair = struct {
    go1: *GameObject,
    go2: *GameObject,
    col1: ?*Collider = null,
    col2: ?*Collider = null,
    tr1: ?*Transform = null,
    tr2: ?*Transform = null,
    rb1: ?*Rigidbody = null,
    rb2: ?*Rigidbody = null,

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
