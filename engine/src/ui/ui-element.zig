const std = @import("std");

const Material = @import("../materials/material.zig").Material;
const UIMaterial = @import("../materials/ui-material.zig").UIMaterial;
const Renderer = @import("../renderer/renderer.zig").Renderer;
const Window = @import("../renderer/window.zig").Window;
const Style = @import("style.zig").Style;
const UINode = @import("ui-node.zig").UINode;

const Length = @import("values/length.zig").Length;

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

    resolved_bounding_top: f32 = 0.0,
    resolved_bounding_left: f32 = 0.0,
    resolved_bounding_width: f32 = 0.0,
    resolved_bounding_height: f32 = 0.0,

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

    pub fn resolveTree(self: *UIElement, unresolved: *bool) !void {
        var context = Context{
            .pen_x = 0,
            .pen_y = 0,
            .element = self,
            .font_size = self.window.root_font_size,
        };

        try self.resolve(unresolved, &context);
    }

    pub fn resolve(self: *UIElement, unresolved: *bool, parent_context: *Context) !void {
        const style = self.style;

        // if this element is resolved just propagate the event to all children
        if (!self.dirty) {
            for (self.children.items) |curr| {
                switch (curr.*) {
                    .element => |el| {
                        try el.resolve(unresolved, parent_context);
                    },
                    .text => continue,
                }
            }

            return;
        }

        var local_unresolved = false;
        if (style.width) |width| {
            self.resolved_width = switch (width) {
                .percent => |_| return error.NotImplemented,
                .keyword => |_| return error.NotImplemented,
                else => resolveAbsoluteLength(self, width, parent_context),
            };
        } else {
            self.resolved_width = 0;
        }

        if (style.height) |height| {
            self.resolved_height = switch (height) {
                .percent => |_| return error.NotImplemented,
                .keyword => |keyword| switch (keyword) {
                    .auto => auto: {
                        var auto_unresolved = false;
                        var min_top: f32 = 9999999;
                        var max_bottom: f32 = -1;

                        if (self.children.items.len == 0) break :auto 0;

                        for (self.children.items) |curr| {
                            switch (curr.*) {
                                .element => |el| {
                                    if (el.dirty) {
                                        unresolved.* = true;
                                        local_unresolved = true;
                                        auto_unresolved = true;
                                        break;
                                    }

                                    if (el.resolved_bounding_top < min_top) {
                                        min_top = el.resolved_bounding_top;
                                    }

                                    if (el.resolved_bounding_height + el.resolved_bounding_top > max_bottom) {
                                        max_bottom = el.resolved_bounding_height + el.resolved_bounding_top;
                                    }
                                },
                                .text => continue,
                            }
                        }

                        break :auto if (auto_unresolved) 0 else max_bottom - min_top;
                    },
                    .min_content => return error.NotImplemented,
                    .max_content => return error.NotImplemented,
                    .fit_content => return error.NotImplemented,
                },
                else => resolveAbsoluteLength(self, height, parent_context),
            };
        } else {
            self.resolved_height = 0;
        }

        var margin_top: f32 = 0;
        var margin_right: f32 = 0;
        var margin_bottom: f32 = 0;
        var margin_left: f32 = 0;

        if (style.margin) |margin| {
            margin_top = switch (margin[0]) {
                .percent => |_| return error.NotImplemented,
                .keyword => |_| return error.NotImplemented,
                else => resolveAbsoluteLength(self, margin[0], parent_context),
            };
            margin_right = switch (margin[1]) {
                .percent => |_| return error.NotImplemented,
                .keyword => |_| return error.NotImplemented,
                else => resolveAbsoluteLength(self, margin[1], parent_context),
            };
            margin_bottom = switch (margin[2]) {
                .percent => |_| return error.NotImplemented,
                .keyword => |_| return error.NotImplemented,
                else => resolveAbsoluteLength(self, margin[2], parent_context),
            };
            margin_left = switch (margin[3]) {
                .percent => |_| return error.NotImplemented,
                .keyword => |_| return error.NotImplemented,
                else => resolveAbsoluteLength(self, margin[3], parent_context),
            };
        }

        if (style.position == .absolute) {
            if (style.top) |top| {
                self.resolved_top = switch (top) {
                    .percent => |_| return error.NotImplemented,
                    .keyword => |_| return error.NotImplemented,
                    else => resolveAbsoluteLength(self, top, parent_context),
                };
            } else {
                self.resolved_top = 0;
            }

            if (style.left) |left| {
                self.resolved_left = switch (left) {
                    .percent => |_| return error.NotImplemented,
                    .keyword => |_| return error.NotImplemented,
                    else => resolveAbsoluteLength(self, left, parent_context),
                };
            } else {
                self.resolved_left = 0;
            }
        } else {
            switch (style.display) {
                .block => {
                    switch (style.position) {
                        .unset => {
                            // Ignore top, left, bottom, and right values
                            self.resolved_top = parent_context.pen_y + margin_top + parent_context.element.resolved_top;
                            self.resolved_left = parent_context.pen_x + margin_left + parent_context.element.resolved_left;

                            parent_context.pen_y += self.resolved_height + margin_top + margin_bottom;
                            parent_context.pen_x = parent_context.padding_left;
                        },
                        else => return error.NotImplemented,
                    }
                },
                .@"inline-block" => {
                    switch (style.position) {
                        .unset => {
                            // Ignore top, left, bottom, and right values
                            self.resolved_top = parent_context.pen_y + margin_top + parent_context.element.resolved_top;
                            self.resolved_left = parent_context.pen_x + margin_left + parent_context.element.resolved_left;

                            parent_context.pen_x += self.resolved_width + margin_left + margin_right;
                        },
                        else => return error.NotImplemented,
                    }
                },
                else => return error.NotImplemented,
            }
        }

        if (style.background_color) |color| {
            self.background_color = color;
        } else {
            self.background_color = .{ 0, 0, 0, 0 };
        }

        self.resolved_bounding_top = self.resolved_top - margin_top;
        self.resolved_bounding_left = self.resolved_left - margin_left;
        self.resolved_bounding_width = self.resolved_width + margin_left + margin_right;
        self.resolved_bounding_height = self.resolved_height + margin_top + margin_bottom;

        if (!local_unresolved) {
            self.dirty = false;
        }

        var padding_left: f32 = 0;
        var padding_right: f32 = 0;
        var padding_top: f32 = 0;
        var padding_bottom: f32 = 0;

        if (style.padding) |padding| {
            padding_left = switch (padding[0]) {
                .percent => |_| return error.NotImplemented,
                .keyword => |_| return error.NotImplemented,
                else => resolveAbsoluteLength(self, padding[0], parent_context),
            };
            padding_right = switch (padding[1]) {
                .percent => |_| return error.NotImplemented,
                .keyword => |_| return error.NotImplemented,
                else => resolveAbsoluteLength(self, padding[1], parent_context),
            };
            padding_top = switch (padding[2]) {
                .percent => |_| return error.NotImplemented,
                .keyword => |_| return error.NotImplemented,
                else => resolveAbsoluteLength(self, padding[2], parent_context),
            };
            padding_bottom = switch (padding[3]) {
                .percent => |_| return error.NotImplemented,
                .keyword => |_| return error.NotImplemented,
                else => resolveAbsoluteLength(self, padding[3], parent_context),
            };
        }

        var font = parent_context.font_size;
        if (style.font_size) |font_size| {
            switch (font_size) {
                .px => |px| font = px,
                .em => |em| font *= em, // font is initially set to parent's font size (1em)
                .rem => |rem| font = self.window.root_font_size * rem,
            }
        }

        var context = Context{
            .pen_x = padding_left,
            .pen_y = padding_top,

            .padding_left = padding_left,
            .padding_right = padding_right,
            .padding_top = padding_top,
            .padding_bottom = padding_bottom,

            .element = self,
        };

        for (self.children.items) |curr| {
            switch (curr.*) {
                .element => |el| {
                    try el.resolve(unresolved, &context);
                },
                .text => continue,
            }
        }
    }

    inline fn resolveAbsoluteLength(self: *UIElement, length: Length, parent_context: *Context) f32 {
        return switch (length) {
            .px => |px| px,
            .em => |em| parent_context.font_size * em,
            .rem => |rem| self.window.root_font_size * rem,
            .vw => |vw| vw * @as(f32, @floatFromInt(self.window.width)),
            .vh => |vh| vh * @as(f32, @floatFromInt(self.window.height)),
            else => 0,
        };
    }
};

const Context = struct {
    pen_x: f32,
    pen_y: f32,

    padding_left: f32 = 0,
    padding_right: f32 = 0,
    padding_top: f32 = 0,
    padding_bottom: f32 = 0,

    font_size: f32 = 0,

    element: *UIElement,
};
