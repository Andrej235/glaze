const std = @import("std");

const c_allocator_util = @import("../utils/c_allocator_util.zig");
const cAlloc = c_allocator_util.cAlloc;
const cFree = c_allocator_util.cFree;

const Timer = @import("../utils/timer.zig").Timer;

const Allocator = std.mem.Allocator;
const HashMap = std.AutoHashMap;

fn HandlerFn(comptime TEventArg: type, comptime TEventData: type) type {
    return *const fn (TEventArg, ?TEventData) anyerror!void;
}

fn HandlerEntry(comptime TEventArg: type, comptime TEventData: type) type {
    return struct {
        callback: HandlerFn(TEventArg, TEventData),
        data: ?TEventData,
        is_paused: bool,
    };
}

fn HashMapEntry(comptime TValue: type, comptime TKey: type) type {
    return struct {
        key_ptr: *TKey,
        value_ptr: *TValue,
    };
}

pub const EntryKey = i64;

pub fn EventDispatcher(comptime TEventArg: type, comptime TEventData: type) type {
    return struct {
        const Self = @This();
        const Fn = HandlerFn(TEventArg, TEventData);
        const HandlerInfo = HandlerEntry(TEventArg, TEventData);
        const HashMapEntryInfo = HashMapEntry(HandlerInfo, EntryKey);

        allocator: Allocator,
        entries: HashMap(EntryKey, HandlerInfo),

        mutex: std.Thread.Mutex,
        next_id: EntryKey = 0,

        /// Creates and allocates memory for event dispatcher
        pub fn create() !*Self {
            const ptr = try cAlloc(Self);
            ptr.* = Self{
                .allocator = std.heap.c_allocator,
                .entries = HashMap(EntryKey, HandlerInfo).init(std.heap.c_allocator),
                .mutex = std.Thread.Mutex{},
            };

            return ptr;
        }

        pub fn destroy(self: *Self) void {
            self.entries.deinit();
            cFree(self);
        }

        pub fn addHandler(self: *Self, handler: Fn, data: ?TEventData) !EntryKey {
            self.mutex.lock();
            defer self.mutex.unlock();

            const id = self.next_id;
            self.next_id += 1;

            self.entries.put(id, HandlerInfo{
                .callback = handler,
                .data = data,
                .is_paused = false,
            }) catch {
                // Decrement id if failed to prevent ghost numbers
                self.next_id -= 1;
                return error.FailedToAddHandler;
            };

            return id;
        }

        /// Removes handler by handler function
        pub fn removeHandler(self: *Self, handler: Fn, data: ?TEventData) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.findEntryByHandlerFn(handler, data)) |entry|
                _ = self.entries.remove(entry.key_ptr.*);
        }

        /// Removes handler by id `(Faster than removeHandler())`
        pub fn removeHandlerById(self: *Self, id: EntryKey) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            _ = self.entries.remove(id);
        }

        /// Pauses handler by handler function
        pub fn pauseHandler(self: *Self, handler: Fn, data: ?TEventData) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.findEntryByHandlerFn(handler, data)) |entry|
                entry.value_ptr.is_paused = true;
        }

        /// Pauses handler by id `(Faster than pauseHandler())`
        pub fn pauseHandlerById(self: *Self, id: EntryKey) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.entries.getPtr(id)) |entry|
                entry.is_paused = true;
        }

        /// Resumes handler by handler function
        pub fn resumeHandler(self: *Self, handler: Fn, data: ?TEventData) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.findEntryByHandlerFn(handler, data)) |entry|
                entry.value_ptr.is_paused = false;
        }

        /// Resumes handler by id `(Faster than resumeHandler())`
        pub fn resumeHandlerById(self: *Self, id: EntryKey) !void {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.entries.getPtr(id)) |entry|
                entry.is_paused = false;
        }

        pub fn dispatch(self: *Self, arg: TEventArg) anyerror!void {
            self.mutex.lock();
            defer self.mutex.unlock();

            var it = self.entries.iterator();

            while (it.next()) |entry| {
                if (!entry.value_ptr.is_paused)
                    try entry.value_ptr.callback(arg, entry.value_ptr.data);
            }
        }

        // --------------------------- HELPER FUNCTIONS --------------------------- //
        fn findEntryByHandlerFn(self: *Self, handler: Fn, data: ?TEventData) ?HashMapEntryInfo {
            var it = self.entries.iterator();

            while (it.next()) |entry| {
                if (entry.value_ptr.callback == handler and entry.value_ptr.data == data)
                    return HashMapEntryInfo{
                        .key_ptr = entry.key_ptr,
                        .value_ptr = entry.value_ptr,
                    };
            }

            return null;
        }
    };
}
