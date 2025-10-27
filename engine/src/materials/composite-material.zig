const std = @import("std");
const Material = @import("./material.zig").Material;

pub const CompositeMaterial = struct {
    material: *Material,

    pub fn create(allocator: *std.heap.ArenaAllocator) anyerror!*CompositeMaterial {
        const vert_src =
            \\#version 300 es
            \\precision mediump float;
            \\
            \\layout(location = 0) in vec2 a_Position;
            \\layout(location = 1) in vec2 a_TexCoord;
            \\
            \\out vec2 v_TexCoord;
            \\
            \\void main() {
            \\    gl_Position = vec4(a_Position, 0.0, 1.0);
            \\    v_TexCoord = a_TexCoord;
            \\}
        ;

        const frag_src =
            \\#version 300 es
            \\precision mediump float;
            \\
            \\in vec2 v_TexCoord;
            \\
            \\uniform sampler2D u_Texture;
            \\out vec4 FragColor;
            \\
            \\void main() {
            \\    FragColor = texture(u_Texture, v_TexCoord);
            \\}
        ;

        const material = try allocator.allocator().create(CompositeMaterial);
        material.* = CompositeMaterial{
            .material = try Material.create(vert_src, frag_src),
        };
        return material;
    }
};
