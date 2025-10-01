const std = @import("std");
const ArrayList = std.ArrayList;

pub const CError = error{NotImplemente};

pub const DynString = struct {
    const offset: u16 = 0;
    size: usize,
    buffer: []u8,
    allocator: *const std.mem.Allocator,

    pub fn init() !*DynString {
        const allocator = std.heap.page_allocator;
        const buffer = try allocator.alloc(u8, 5);
        const instance = try allocator.create(DynString);

        instance.* = DynString{ .allocator = &allocator, .size = offset, .buffer = buffer };
        return instance;
    }

    pub fn initConstText(str: []const u8) !*DynString {
        const allocator = std.heap.page_allocator;
        const buffer = try allocator.alloc(u8, str.len);
        const instance = try allocator.create(DynString);

        instance.* = DynString{ .allocator = &allocator, .size = offset, .buffer = buffer };
        try instance.setConstText(str);

        return instance;
    }

    pub fn initText(str: []u8) !*DynString {
        const allocator = std.heap.page_allocator;
        const buffer = try allocator.alloc(u8, str.len);
        const instance = try allocator.create(DynString);

        instance.* = DynString{ .allocator = &allocator, .size = offset, .buffer = buffer };
        try instance.setText(str);

        return instance;
    }

    pub fn deinit(self: *DynString) void {
        self.allocator.free(self.buffer);
        self.allocator.destroy(self);
    }

    pub fn appendConst(_: *DynString, _: []const u8) !void {
        return CError.NotImplemente;
    }

    pub fn setConstText(self: *DynString, str: []const u8) !void {
        self.buffer = try self.allocator.realloc(self.buffer, str.len);
        std.mem.copyForwards(u8, self.buffer, str);
    }

    pub fn setText(self: *DynString, str: []u8) !void {
        self.buffer = try self.allocator.realloc(self.buffer, str.len);
        std.mem.copyForwards(u8, self.buffer, str);
    }

    pub fn toUpper(self: *DynString) void {
        for (0..self.buffer.len) |index| {
            if (self.buffer[index] >= 'a' and self.buffer[index] <= 'z') {
                self.buffer[index] = self.buffer[index] - ('a' - 'A');
            }
        }
    }

    pub fn toLower(self: *DynString) void {
        for (0..self.buffer.len) |index| {
            if (self.buffer[index] >= 'A' and self.buffer[index] <= 'Z') {
                self.buffer[index] = self.buffer[index] + 32;
            }
        }
    }

    pub fn print(self: *DynString) void {
        std.debug.print("{s}", .{self.buffer});
    }

    // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    // STATIC METHODS
    // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    pub fn deinitArrayList(gpa: std.mem.Allocator, list: *ArrayList(*DynString)) !void {
        for (list.items) |value| {
            value.deinit();
        }

        list.deinit(gpa);
    }
};
