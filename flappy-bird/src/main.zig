const std = @import("std");
const a = @import("glaze");

pub fn main() !void {
    try a.main();
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
}
