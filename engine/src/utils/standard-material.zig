const std = @import("std");
const Material = @import("./material.zig").Material;

pub const StandardMaterial = struct {
    material: *Material,

    pub fn create(allocator: *std.heap.ArenaAllocator) anyerror!*StandardMaterial {
        const vert_src =
            \\#version 330 core
            \\
            \\layout(location = 0) in vec2 a_Position;
            \\layout(location = 1) in vec2 a_TexCoord;
            \\
            \\uniform mat4 u_Model;
            \\uniform mat4 u_Projection;
            \\
            \\out vec2 v_TexCoord;
            \\
            \\void main() {
            \\    vec4 worldPos = u_Model * vec4(a_Position, 0.0, 1.0);
            \\    gl_Position = u_Projection * worldPos;
            \\    v_TexCoord = a_TexCoord;
            \\}
        ;

        const frag_src =
            \\#version 330 core
            \\precision mediump float;
            \\
            \\in vec2 v_TexCoord;
            \\
            \\uniform sampler2D u_Texture;
            \\
            \\void main() {
            \\    gl_FragColor = texture(u_Texture, v_TexCoord);
            \\}
        ;

        const material = try allocator.allocator().create(StandardMaterial);
        material.* = StandardMaterial{
            .material = try Material.create(vert_src, frag_src),
        };
        return material;
    }
};
