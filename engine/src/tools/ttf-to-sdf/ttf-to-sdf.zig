const std = @import("std");
const getTtfFilePaths = @import("get-ttf-files.zig").getTtfFilePaths;

pub fn main() !void {
    const files = try getTtfFilePaths();

    for (files.items) |file_path| {
        std.debug.print("Processing file: {s}\n", .{file_path});
        // Add your SDF conversion logic here
    }
}
