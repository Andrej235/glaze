const std = @import("std");

const Material = @import("../materials/material.zig").Material;
const UIMaterial = @import("../materials/ui-material.zig").UIMaterial;
const Renderer = @import("../renderer/renderer.zig").Renderer;
const UINode = @import("ui-node.zig").UINode;
const Style = @import("style.zig").Style;

pub const UIElement = struct {
    children: std.ArrayList(*UINode),
    parent: ?*UIElement = null,
    material: ?*Material = null,

    resolved_top: f32 = 0.0,
    resolved_left: f32 = 0.0,
    resolved_width: f32 = 0.0,
    resolved_height: f32 = 0.0,

    background_color: [4]f32 = .{ 0.0, 0.0, 0.0, 0.0 },
    styles: std.ArrayList(Style) = undefined,

    pub fn init() !*UIElement {
        const element = try std.heap.c_allocator.create(UIElement);
        element.* = UIElement{
            .children = std.ArrayList(*UINode){},
        };

        return element;
    }

    pub fn addChild(self: *UIElement, node: *UINode) !void {
        switch (node.*) {
            .element => |el| {
                el.parent = self;
            },
            .text => |txt| {
                txt.parent = self;
            },
        }

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
            self.resolved_width, 0,                    0, 0,
            0,                   self.resolved_height, 0, 0,
            0,                   0,                    1, 0,
            self.resolved_left,  self.resolved_top,    0, 1,
        };
    }

    pub fn resolve(self: *UIElement) void {
        _ = self;
    }
};
