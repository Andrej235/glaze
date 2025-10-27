const std = @import("std");
const UITextNode = @import("ui-text-node.zig").UITextNode;
const UIElement = @import("ui-element.zig").UIElement;

pub const UINode = union(enum) {
    text: *UITextNode,
    element: *UIElement,

    pub fn createElement() !*UINode {
        const node = try std.heap.c_allocator.create(UINode);
        node.* = .{ .element = try UIElement.init() };
        return node;
    }
};
