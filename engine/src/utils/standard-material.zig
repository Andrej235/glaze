const std = @import("std");
const Material = @import("./material.zig").Material;

pub const StandardMaterial = struct {
    material: *Material,

    pub fn create(allocator: *std.heap.ArenaAllocator) anyerror!*StandardMaterial {
        const vert_src =
            \\#version 330 core
            \\
            \\layout(location = 0) in vec2 position;
            \\
            \\uniform mat4 u_Model;
            \\uniform mat4 u_Projection;
            \\
            \\void main() {
            \\    vec4 worldPos = u_Model * vec4(position, 0.0, 1.0);
            \\    gl_Position = u_Projection * worldPos;
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
