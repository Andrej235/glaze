const std = @import("std");

const Material = @import("../materials/material.zig").Material;
const UIMaterial = @import("../materials/ui-material.zig").UIMaterial;
const Renderer = @import("../renderer/renderer.zig").Renderer;
const UINode = @import("ui-node.zig").UINode;

pub const UIElement = struct {
    children: std.ArrayList(*UINode),
    parent: ?*UIElement = null,
    material: ?*Material = null,

    pub fn init() !*UIElement {
        const element = try std.heap.c_allocator.create(UIElement);
        element.* = UIElement{
            .children = std.ArrayList(*UINode){},
        };

        return element;
    }

    pub fn addChild(self: *UIElement, node: *UINode) !void {
        try self.children.append(std.heap.c_allocator, node);
    }

    pub fn getMaterial(self: *UIElement) !*Material {
        if (self.material == null) {
            const cache = try Renderer.cacheMaterial(UIMaterial);
            self.material = cache.material;
        }

        return self.material.?;
    }

    pub fn makeModelMatrix(_: *UIElement, x: f32, y: f32, w: f32, h: f32) [16]f32 {
        return .{
            w, 0, 0, 0,
            0, h, 0, 0,
            0, 0, 1, 0,
            x, y, 0, 1,
        };
    }
};
