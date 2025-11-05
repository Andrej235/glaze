const std = @import("std");
const Material = @import("./material.zig").Material;

pub const TextMaterial = struct {
    material: *Material,

    pub fn create(allocator: *std.heap.ArenaAllocator) anyerror!*TextMaterial {
        const vert_src =
            \\#version 300 es
            \\precision mediump float;
            \\
            \\layout(location = 0) in vec2 a_Position;
            \\layout(location = 1) in vec2 a_TexCoord;
            \\
            \\out vec2 v_TexCoord;
            \\
            \\uniform mat4 u_Projection;
            \\
            \\void main() {
            \\    v_TexCoord = a_TexCoord;
            \\    gl_Position = u_Projection * vec4(a_Position, 0.0, 1.0);
            \\}
        ;

        const frag_src =
            \\#version 300 es
            \\precision mediump float;
            \\
            \\in vec2 v_TexCoord;
            \\out vec4 fragColor;
            \\
            \\uniform sampler2D u_Texture;
            \\uniform vec3 u_Color;
            \\uniform float u_PixelRange; // from JSON: atlas.distanceRange
            \\
            \\// For MSDF median edge
            \\float median(float r, float g, float b) {
            \\    return max(min(r, g), min(max(r, g), b));
            \\}
            \\
            \\void main() {
            \\    vec3 msdf = texture(u_Texture, v_TexCoord).rgb;
            \\
            \\    // Decode signed distance from RGB
            \\    float sd = median(msdf.r, msdf.g, msdf.b);
            \\    sd = sd * 2.0 - 1.0;
            \\
            \\    // Smooth alpha — scale by MSDF range
            \\    float dist = sd * 6.;
            \\    float alpha = clamp(dist + 0.5, 0.0, 1.0);
            \\
            \\    if (alpha < 0.001) discard; // clean crisp glyph edges
            \\
            \\    fragColor = vec4(u_Color, alpha);
            \\}
        ;

        const material = try allocator.allocator().create(TextMaterial);
        material.* = TextMaterial{
            .material = try Material.create(vert_src, frag_src),
        };
        return material;
    }
};
