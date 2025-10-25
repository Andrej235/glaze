const std = @import("std");
const getZxFiles = @import("./node-parser/get-zx-files.zig").getZxFilePaths;

const nodes_module = @import("./node-parser/nodes.zig");
const tokens_module = @import("./node-parser/tokens.zig");

const Attribute = @import("node-parser/attribute.zig").Attribute;
const Node = nodes_module.Node;
const ElementNode = nodes_module.ElementNode;
const Token = tokens_module.Token;
const TagType = tokens_module.TagType;

const parseTags = @import("./node-parser/parse-tags.zig").parseTags;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const zxFiles = try getZxFiles();

    var cwd = std.fs.cwd();
    for (zxFiles.items) |zxFilePath| {
        std.debug.print("--- {s} ---\n", .{zxFilePath});

        var file = try cwd.openFile(zxFilePath, .{ .mode = .read_write });
        defer file.close();

        var content = try file.readToEndAlloc(allocator, 1024);

        const tags = try parseTags(&content);

        std.debug.print("Total: {}\n\n", .{tags.items.len});

        const nodes = try parseNodes(content, tags.items, allocator, 0);
        const root_nodes = nodes.nodes;
        for (root_nodes.items) |node|
            printNode(node, 0);

        std.debug.print("\n\n\n", .{});
    }
}

fn printNode(node: Node, indent: usize) void {
    printIndent(indent);
    switch (node) {
        .element => |el| {
            std.debug.print("<>{s}\n", .{el.tag_name});
            for (el.children.?.items) |child| printNode(child, indent + 2);
        },
        .text => |txt| std.debug.print("T | {s}\n", .{txt}),
        .dynamic => |expr| std.debug.print("E | {s}\n", .{expr}),
    }
}

fn printIndent(level: usize) void {
    for (0..level) |_| {
        std.debug.print(" ", .{});
    }
}

pub fn parseNodes(source: []const u8, tokens: []const Token, allocator: std.mem.Allocator, start_index: usize) !struct {
    nodes: std.ArrayList(Node),
    next_index: usize,
} {
    var nodes = std.ArrayList(Node){};
    var i = start_index;

    while (i < tokens.len) {
        const token = tokens[i];
        switch (token) {
            .opening_tag => |tag| {
                // Create node for this tag
                var node = Node{ .element = ElementNode{
                    .tag_name = source[tag.name_start..tag.name_end],
                    .attributes = tag.attributes,
                    .children = std.ArrayList(Node){},

                    .start_location = tag.start,
                    .end_location = tag.end,
                } };

                // Recursively parse children
                const child_result = try parseNodes(source, tokens, allocator, i + 1);
                node.element.children = child_result.nodes;

                // Add this node to the current list
                try nodes.append(allocator, node);

                // Move index to after the closing tag
                i = child_result.next_index;
            },
            .self_closing_tag => |tag| {
                try nodes.append(allocator, Node{
                    .element = ElementNode{
                        .tag_name = source[tag.name_start..tag.name_end],
                        .attributes = tag.attributes,
                        .children = std.ArrayList(Node){},

                        .start_location = tag.start,
                        .end_location = tag.end,
                    },
                });
                i += 1;
            },
            .closing_tag => {
                // We reached the end of this block
                return .{
                    .nodes = nodes,
                    .next_index = i + 1,
                };
            },
            .text => |text| {
                try nodes.append(allocator, Node{
                    .text = source[text.start_location..text.end_location],
                });
                i += 1;
            },
            .dynamic => |dynamic| {
                try nodes.append(allocator, Node{
                    .dynamic = source[dynamic.start_location..dynamic.end_location],
                });
                i += 1;
            },
        }
    }

    return .{
        .nodes = nodes,
        .next_index = i,
    };
}
