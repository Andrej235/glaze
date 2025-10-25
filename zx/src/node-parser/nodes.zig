const std = @import("std");
const Attribute = @import("./attribute.zig").Attribute;

pub const Node = union(enum) {
    element: ElementNode,
    text: []const u8,
    dynamic: []const u8,

    pub fn printAsTree(self: *const Node) void {
        printNodeInternal(self, 0);
    }

    fn printNodeInternal(node: *const Node, indent: usize) void {
        printIndent(indent);
        switch (node.*) {
            .element => |el| {
                std.debug.print("<>{s}\n", .{el.tag_name});
                for (el.children.items) |child| printNodeInternal(&child, indent + 2);
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
};

pub const ElementNode = struct {
    tag_name: []const u8,
    attributes: std.ArrayList(Attribute),
    children: std.ArrayList(Node),

    start_location: u32,
    end_location: u32,
};
