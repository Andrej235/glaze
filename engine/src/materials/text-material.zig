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
            \\uniform vec4 u_Color;
            \\uniform float u_PixelRange; // atlas.distanceRange (e.g. 6.0)
            \\
            \\float median3(float r, float g, float b) {
            \\    return max(min(r, g), min(max(r, g), b));
            \\}
            \\
            \\void main() {
            \\    vec3 sampleRGB = texture(u_Texture, v_TexCoord).rgb;
            \\    float sd = median3(sampleRGB.r, sampleRGB.g, sampleRGB.b);
            \\    sd = sd * 2.0 - 1.0; // map to signed distance (-1..1)
            \\
            \\    // Screen-space smoothing using derivatives
            \\    vec2 px = fwidth(v_TexCoord);
            \\    float screenPxRange = 16. * inversesqrt(px.x * px.x + px.y * px.y);
            \\
            \\    float alpha = clamp(sd * screenPxRange + 0.5, 0.0, 1.0);
            \\
            \\    // Gamma correct
            \\    alpha = pow(alpha, 1.0 / 2.2);
            \\
            \\    fragColor = vec4(u_Color.rgb, u_Color.a * alpha);
            \\}
        ;

        const material = try allocator.allocator().create(TextMaterial);
        material.* = TextMaterial{
            .material = try Material.create(vert_src, frag_src),
        };
        return material;
    }
};
