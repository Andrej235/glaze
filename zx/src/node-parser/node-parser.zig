const std = @import("std");

const Node = @import("./nodes.zig").Node;
const ElementNode = @import("./nodes.zig").ElementNode;
const Token = @import("./tokens.zig").Token;

const parseTags = @import("./parse-tags.zig").parseTags;

pub fn parseNodes(source: []const u8, allocator: std.mem.Allocator) !std.ArrayList(Node) {
    const tokens = try parseTags(&source);
    const result = try parseNodesInternal(source, tokens.items, allocator, 0);
    return result.nodes;
}

fn parseNodesInternal(source: []const u8, tokens: []const Token, allocator: std.mem.Allocator, start_index: usize) !struct {
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
                const child_result = try parseNodesInternal(source, tokens, allocator, i + 1);
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
