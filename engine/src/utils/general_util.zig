const std = @import("std");
const TypeId = u32;

pub fn fnId(fn_ptr: anytype) TypeId {
    const addr = @intFromPtr(fn_ptr);
    return @truncate(addr);
}
