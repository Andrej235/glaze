const std = @import("std");

const Material = @import("../materials/material.zig").Material;
const UIMaterial = @import("../materials/ui-material.zig").UIMaterial;
const Renderer = @import("../renderer/renderer.zig").Renderer;
const Window = @import("../renderer/window.zig").Window;
const Style = @import("style.zig").Style;
const UINode = @import("ui-node.zig").UINode;

pub const UIElement = struct {
    window: *Window,

    dirty: bool = true,

    children: std.ArrayList(*UINode),
    parent: ?*UIElement = null,
    material: ?*Material = null,

    resolved_top: f32 = 0.0,
    resolved_left: f32 = 0.0,
    resolved_width: f32 = 0.0,
    resolved_height: f32 = 0.0,

    background_color: [4]f32 = .{ 0.0, 0.0, 0.0, 0.0 },
    style: Style,

    pub fn init() !*UIElement {
        const element = try std.heap.c_allocator.create(UIElement);
        element.* = UIElement{
            .children = std.ArrayList(*UINode){},
            .style = Style{},
            .window = try Renderer.getWindow(),
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

    pub fn makeDirty(self: *UIElement) void {
        self.dirty = true;

        for (self.children.items) |curr| {
            switch (curr.*) {
                .element => |el| {
                    el.makeDirty();
                },
                .text => continue,
            }
        }
    }

    pub fn resolve(self: *UIElement, unresolved: *bool) !void {
        const style = self.style;

        if (!self.dirty) {
            for (self.children.items) |curr| {
                switch (curr.*) {
                    .element => |el| {
                        try el.resolve(unresolved);
                    },
                    .text => continue,
                }
            }

            return;
        }

        var local_unresolved = false;
        if (style.width) |width| {
            self.resolved_width = switch (width) {
                .px => |px| px,
                .em => |_| return error.NotImplemented,
                .rem => |_| return error.NotImplemented,
                .vw => |vw| vw * @as(f32, @floatFromInt(self.window.width)),
                .vh => |vh| vh * @as(f32, @floatFromInt(self.window.height)),
                .percent => |_| return error.NotImplemented,
                .keyword => |_| return error.NotImplemented,
            };
        } else {
            self.resolved_width = 0;
        }

        if (style.height) |height| {
            self.resolved_height = switch (height) {
                .px => |px| px,
                .em => |_| return error.NotImplemented,
                .rem => |_| return error.NotImplemented,
                .vw => |vw| vw * @as(f32, @floatFromInt(self.window.width)),
                .vh => |vh| vh * @as(f32, @floatFromInt(self.window.height)),
                .percent => |_| return error.NotImplemented,
                .keyword => |keyword| switch (keyword) {
                    .auto => auto: {
                        var max: f32 = -1;
                        if (self.children.items.len == 0) break :auto 0;

                        for (self.children.items) |curr| {
                            switch (curr.*) {
                                .element => |el| {
                                    if (el.dirty) {
                                        unresolved.* = true;
                                        local_unresolved = true;
                                        max = -1;
                                        break;
                                    }

                                    if (el.resolved_height > max) {
                                        max = el.resolved_height;
                                    }
                                },
                                .text => continue,
                            }
                        }

                        break :auto if (max < 0) 0 else max;
                    },
                    .min_content => return error.NotImplemented,
                    .max_content => return error.NotImplemented,
                    .fit_content => return error.NotImplemented,
                },
            };
        } else {
            self.resolved_height = 0;
        }

        if (style.top) |top| {
            self.resolved_top = switch (top) {
                .px => |px| px,
                .em => |_| return error.NotImplemented,
                .rem => |_| return error.NotImplemented,
                .vw => |vw| vw * @as(f32, @floatFromInt(self.window.width)),
                .vh => |vh| vh * @as(f32, @floatFromInt(self.window.height)),
                .percent => |_| return error.NotImplemented,
                .keyword => |_| return error.NotImplemented,
            };
        } else {
            self.resolved_top = 0;
        }

        if (style.left) |left| {
            self.resolved_left = switch (left) {
                .px => |px| px,
                .em => |_| return error.NotImplemented,
                .rem => |_| return error.NotImplemented,
                .vw => |vw| vw * @as(f32, @floatFromInt(self.window.width)),
                .vh => |vh| vh * @as(f32, @floatFromInt(self.window.height)),
                .percent => |_| return error.NotImplemented,
                .keyword => |_| return error.NotImplemented,
            };
        } else {
            self.resolved_left = 0;
        }

        if (style.background_color) |color| {
            self.background_color = color;
        } else {
            self.background_color = .{ 0, 0, 0, 0 };
        }

        if (!local_unresolved) {
            self.dirty = false;
        }

        for (self.children.items) |curr| {
            switch (curr.*) {
                .element => |el| {
                    try el.resolve(unresolved);
                },
                .text => continue,
            }
        }
    }
};
