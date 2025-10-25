const std = @import("std");

pub fn getZxFilePaths() !std.ArrayList([]const u8) {
    var dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();

    var zxFiles = std.ArrayList([]const u8){};
    try findZxFiles(&dir, &zxFiles, ".");

    return zxFiles;
}

fn findZxFiles(dir: *std.fs.Dir, list: *std.ArrayList([]const u8), path: []const u8) !void {
    const allocator = std.heap.page_allocator;

    var it = dir.iterate();
    while (try it.next()) |curr| {
        const curr_path = try std.mem.concat(allocator, u8, &[_][]const u8{ path, "/", curr.name });

        switch (curr.kind) {
            .directory => {
                var new_dir = try dir.openDir(curr.name, .{ .iterate = true });
                defer new_dir.close();
                try findZxFiles(&new_dir, list, curr_path);
            },
            .file => {
                if (std.mem.endsWith(u8, curr.name, ".zx")) {
                    try list.append(allocator, curr_path);
                }
            },
            else => {},
        }
    }
}
