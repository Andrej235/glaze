const std = @import("std");

const Renderer = @import("../renderer/renderer.zig").Renderer;
const Material = @import("../materials/material.zig").Material;
const UIMaterial = @import("../materials/ui-material.zig").UIMaterial;
const UIElement = @import("ui-element.zig").UIElement;

pub const UITextNode = struct {
    parent: ?*UIElement = null,
    material: ?*Material = null,
    text: []const u8 = "",

    pub fn getMaterial(self: *UIElement) !*Material {
        if (self.material == null) {
            const cache = try Renderer.cacheMaterial(UIMaterial);
            self.material = cache.material;
        }

        return self.material.?;
    }
};
