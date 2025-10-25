const std = @import("std");
const Attribute = @import("./attribute.zig").Attribute;

pub const Node = union(enum) {
    element: ElementNode,
    text: []const u8,
    dynamic: []const u8,
};

pub const ElementNode = struct {
    tag_name: []const u8,
    attributes: ?std.ArrayList(Attribute),
    children: ?std.ArrayList(Node),

    start_location: u32,
    end_location: u32,
};