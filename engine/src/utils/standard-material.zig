const std = @import("std");
const Material = @import("./material.zig").Material;

pub const StandardMaterial = struct {
    material: *Material,

    pub fn create(allocator: *std.heap.ArenaAllocator) anyerror!*StandardMaterial {
        const vert_src =
            \\#version 100
            \\attribute vec2 position;
            \\void main() {
            \\    gl_Position = vec4(position, 0.0, 1.0);
            \\}
        ;
        const frag_src =
            \\#version 100
            \\precision mediump float;
            \\void main() {
            \\    gl_FragColor = vec4(1.0, 0.5, 0.2, 1.0);
            \\}
        ;

        const material = try allocator.allocator().create(StandardMaterial);
        material.* = StandardMaterial{
            .material = try Material.create(vert_src, frag_src),
        };
        return material;
    }
};
