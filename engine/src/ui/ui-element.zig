const std = @import("std");

const Material = @import("../materials/material.zig").Material;
const UIMaterial = @import("../materials/ui-material.zig").UIMaterial;
const Renderer = @import("../renderer/renderer.zig").Renderer;
const UINode = @import("ui-node.zig").UINode;

pub const UIElement = struct {
    children: std.ArrayList(*UINode),
    parent: ?*UIElement = null,
    material: ?*Material = null,

    top: f32 = 0.0,
    left: f32 = 0.0,
    width: f32 = 0.0,
    height: f32 = 0.0,

    background_color: [4]f32 = .{ 0.0, 0.0, 0.0, 0.0 },

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

    pub fn makeModelMatrix(self: *UIElement) [16]f32 {
        return .{
            self.width, 0,           0, 0,
            0,          self.height, 0, 0,
            0,          0,           1, 0,
            self.left,  self.top,    0, 1,
        };
    }
};
