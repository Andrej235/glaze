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
            \\    gl_Position = vec4(a_Position, 0.0, 1.0);
            \\}
        ;

        const frag_src =
            \\#version 300 es
            \\precision highp float;
            \\
            \\in vec2 v_TexCoord;
            \\out vec4 FragColor;
            \\
            \\uniform sampler2D u_Texture;   // atlas bound to texture unit 0
            \\uniform vec4 u_Color;       // rgba color
            \\
            \\// median helper
            \\float median(float a, float b, float c) {
            \\    return max(min(a,b), min(max(a,b), c));
            \\}
            \\
            \\void main() {
            \\    vec3 msdf = texture(u_Texture, v_TexCoord).rgb;
            \\    float sd = median(msdf.r, msdf.g, msdf.b) - 0.5; // normalized signed distance
            \\
            \\    // convert normalized distance to approximate screen px distance
            \\    float screenDist = sd * 6.; // TODO: change 6 with distanceRange from font metadata
            \\
            \\    // compute anti-aliased alpha using fwidth
            \\    float afwidth = max(0.5 * fwidth(screenDist), 1e-6);
            \\    // smooth step centered at zero distance
            \\    float alpha = smoothstep(afwidth, -afwidth, screenDist); // note reversed to map 0->1
            \\
            \\    FragColor = vec4(1.0);
            \\
            \\    if (FragColor.a <= 0.001) discard;
            \\}
        ;

        const material = try allocator.allocator().create(TextMaterial);
        material.* = TextMaterial{
            .material = try Material.create(vert_src, frag_src),
        };
        return material;
    }
};
