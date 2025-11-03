const std = @import("std");

const Material = @import("../materials/material.zig").Material;
const TextMaterial = @import("../materials/text-material.zig").TextMaterial;
const Renderer = @import("../renderer/renderer.zig").Renderer;
const Font = @import("font.zig").Font;
const UIElement = @import("ui-element.zig").UIElement;

pub const UITextNode = struct {
    parent: ?*UIElement = null,
    material: ?*Material = null,
    font: *Font,
    text: []const u8 = "",

    pub fn getMaterial(self: *UITextNode) !*Material {
        if (self.material == null) {
            const cache = try Renderer.cacheMaterial(TextMaterial);
            self.material = cache.material;
        }

        return self.material.?;
    }

    pub fn init(text: []const u8, font: *Font) !*UITextNode {
        const element = try std.heap.c_allocator.create(UITextNode);
        element.* = UITextNode{
            .font = font,
            .text = text,
        };

        return element;
    }
};
