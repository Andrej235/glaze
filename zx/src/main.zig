const std = @import("std");
const getZxFiles = @import("./node-parser/get-zx-files.zig").getZxFilePaths;

const nodes_module = @import("./node-parser/nodes.zig");
const tokens_module = @import("./node-parser/tokens.zig");

const Attribute = @import("node-parser/attribute.zig").Attribute;
const Node = nodes_module.Node;
const ElementNode = nodes_module.ElementNode;
const Token = tokens_module.Token;
const TagType = tokens_module.TagType;

const parseNodes = @import("./node-parser/node-parser.zig").parseNodes;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const zxFiles = try getZxFiles();

    var cwd = std.fs.cwd();
    for (zxFiles.items) |zxFilePath| {
        std.debug.print("--- {s} ---\n", .{zxFilePath});

        var file = try cwd.openFile(zxFilePath, .{ .mode = .read_write });
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1024);
        const nodes = try parseNodes(content, allocator);

        for (nodes.items) |node|
            node.printAsTree();

        std.debug.print("\n", .{});
    }
}
