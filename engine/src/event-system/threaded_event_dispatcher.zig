const std = @import("std");

const c_allocator_util = @import("../utils/c_allocator_util.zig");
const cAlloc = c_allocator_util.cAlloc;
const cFree = c_allocator_util.cFree;

const Timer = @import("../utils/timer.zig").Timer;

const Thread = std.Thread;
const Mutex = std.Thread.Mutex;
const Condition = std.Thread.Condition;
const ArrayList = std.ArrayList;

fn HandlerFn(comptime TEventArg: type, comptime TEventData: type) type {
    return *const fn (TEventArg, ?TEventData) anyerror!void;
}

fn HandlerEntry(comptime TEventArg: type, comptime TEventData: type) type {
    return struct {
        callback: HandlerFn(TEventArg, TEventData),
        data: ?TEventData,
    };
}

pub fn ThreadedEventDispatcher(comptime TEventArg: type, comptime TEventData: type) type {
    return struct {
        const Self = @This();
        const JobHandler = ThreadJobHandler(TEventArg, TEventData);

        thread_job_handlers: ArrayList(*JobHandler),

        cpu_thread_count: usize,

        mutex: Mutex,

        pub fn create() !*Self {
            // Get cpu thread count
            const thread_count: usize = try std.Thread.getCpuCount();

            // Initialize thread job handlers
            const allocator: std.mem.Allocator = std.heap.c_allocator;
            var thread_job_handlers = try ArrayList(*JobHandler).initCapacity(std.heap.c_allocator, thread_count);
            for (0..thread_count) |_| {
                const thread_job_handler = try JobHandler.create();
                try thread_job_handler.initThread();
                try thread_job_handlers.append(allocator, thread_job_handler);
            }

            const instance: *Self = try cAlloc(Self);
            instance.* = Self{
                .cpu_thread_count = thread_count,
                .thread_job_handlers = thread_job_handlers,
                .mutex = Mutex{},
            };

            return instance;
        }

        pub fn destroy(_: *Self) void {}

        pub fn addHandler(self: *Self, handler: HandlerFn(TEventArg, TEventData), data: ?TEventData) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            // Find job handler with least entries
            var job_handler: ?*JobHandler = null;
            var number_of_entries: usize = std.math.maxInt(usize);

            for (self.thread_job_handlers.items) |thread_job_handler| {
                const number_of_entries_of_job_handler: usize = thread_job_handler.getCurrentNumberOfEntries();

                if (number_of_entries_of_job_handler < number_of_entries) {
                    job_handler = thread_job_handler;
                    number_of_entries = number_of_entries_of_job_handler;
                }
            }

            if (job_handler) |jh| {
                try jh.addEntry(handler, data);
            }
        }

        pub fn removeHandler(self: *Self, handler: HandlerFn(TEventArg, TEventData), data: ?TEventData) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            for (self.thread_job_handlers.items) |thread_job_handler| {
                const removed = thread_job_handler.removeEntry(handler, data);

                // Break out of loop if entry was removed
                if (removed) break;
            }
        }

        pub fn dispatch(self: *Self, event: TEventArg) anyerror!void {
            self.mutex.lock();
            defer self.mutex.unlock();

            std.debug.print("\n\n\n\n\n", .{});

            for (self.thread_job_handlers.items) |thread_job_handler| {
                std.debug.print("\nDispatched", .{});
                thread_job_handler.dispatch(event);
            }
        }
    };
}

pub fn ThreadJobHandler(comptime TEventArg: type, comptime TEventData: type) type {
    return struct {
        const Self = @This();
        const Fn = HandlerFn(TEventArg, TEventData);
        const Entry = HandlerEntry(TEventArg, TEventData);

        allocator: std.mem.Allocator,

        event_data: TEventArg,
        handlers_entry: ArrayList(Entry),

        thread: Thread,
        mutex: Mutex,
        condition: Condition,
        should_dispatch: bool,

        pub fn create() !*Self {
            const allocator: std.mem.Allocator = std.heap.c_allocator;

            const instance: *Self = try cAlloc(Self);
            instance.* = Self{
                .allocator = std.heap.c_allocator,
                .event_data = undefined,
                .handlers_entry = try ArrayList(Entry).initCapacity(allocator, 10),
                .thread = undefined,
                .mutex = Mutex{},
                .condition = Condition{},
                .should_dispatch = false,
            };

            return instance;
        }

        pub fn initThread(self: *Self) !void {
            self.thread = try Thread.spawn(.{}, threadLoop, .{self});
        }

        pub fn addEntry(self: *Self, handler: Fn, data: ?TEventData) !void {
            try self.handlers_entry.append(self.allocator, Entry{ .callback = handler, .data = data });
        }

        /// Tries to remove entry from thread job handler
        ///
        /// ### Arguments
        /// - `handler`: Handler to remove
        /// - `data`: Data to remove
        ///
        /// ### Returns
        /// - `true` if entry was removed
        /// - `false` if entry was not found
        pub fn removeEntry(self: *Self, handler: Fn, data: ?TEventData) bool {
            for (self.handlers_entry.items, 0..) |entry, i| {
                if (entry.callback == handler and entry.data == data) {
                    _ = self.handlers_entry.swapRemove(i);
                    return true;
                }
            }

            return false;
        }

        pub fn dispatch(self: *Self, event: TEventArg) void {
            self.mutex.lock();
            defer self.mutex.unlock();

            std.debug.print("\nWorking on: {}", .{self.handlers_entry.items.len});

            self.event_data = event;
            self.should_dispatch = true;
            self.condition.signal();
        }

        pub fn getCurrentNumberOfEntries(self: *Self) usize {
            return self.handlers_entry.items.len;
        }

        fn threadLoop(self: *Self) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            while (true) {
                while (!self.should_dispatch) {
                    self.condition.wait(&self.mutex);
                }

                self.should_dispatch = false;

                const handlers = self.handlers_entry.items;
                const event = self.event_data;

                for (handlers) |entry| {
                    try entry.callback(event, entry.data);
                }
            }
        }
    };
}
