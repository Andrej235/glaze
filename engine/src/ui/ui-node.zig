const std = @import("std");

const UIElement = @import("ui-element.zig").UIElement;
const UITextNode = @import("ui-text-node.zig").UITextNode;

const Font = @import("font.zig").Font;

pub const UINode = union(enum) {
    text: *UITextNode,
    element: *UIElement,

    pub fn createElement() !*UINode {
        const node = try std.heap.c_allocator.create(UINode);
        node.* = .{ .element = try UIElement.init() };
        return node;
    }

    pub fn createTextNode(text: []const u8, font: *Font) !*UINode {
        const node = try std.heap.c_allocator.create(UINode);
        node.* = .{ .text = try UITextNode.init(text, font) };
        return node;
    }
};
