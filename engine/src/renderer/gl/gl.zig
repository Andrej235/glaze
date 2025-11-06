const std = @import("std");

const GlContext = @import("gl-context.zig").GlContext;
const SceneRenderingBuffers = @import("scene-rendering-buffers.zig").SceneRenderingBuffers;
const UiRenderingBuffers = @import("ui-rendering-buffers.zig").UiRenderingBuffers;
const CompositePassBuffers = @import("composite-pass-buffers.zig").CompositePassBuffers;

const c = @cImport({
    @cInclude("../src/renderer/gl/glad/include/glad/gl.h");
});

pub const Gl = struct {
    context: *GlContext,
    scene_buffers: SceneRenderingBuffers,
    ui_buffers: UiRenderingBuffers,
    composite_buffers: CompositePassBuffers,

    pub fn init(
        ctx: *GlContext,
        window_width: i32,
        window_height: i32,
    ) !Gl {
        try ctx.loadGlad(ctx);

        // enable alpha blending
        c.glEnable(c.GL_BLEND);
        c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

        const self = Gl{
            .context = ctx,
            .scene_buffers = try initSceneBuffers(),
            .ui_buffers = try initUiBuffers(window_width, window_height),
            .composite_buffers = try initCompositeBuffers(),
        };
        return self;
    }

    fn initSceneBuffers() !SceneRenderingBuffers {
        var buffers = SceneRenderingBuffers{
            .vao = 0,
            .vbo = 0,
            .ebo = 0,
        };

        c.glGenVertexArrays(1, &buffers.vao);
        c.glBindVertexArray(buffers.vao);

        // VBO
        const vertices = [_]f32{
            -0.5, 0.5,  0.0, 1.0,
            -0.5, -0.5, 0.0, 0.0,
            0.5,  -0.5, 1.0, 0.0,
            0.5,  0.5,  1.0, 1.0,
        };
        c.glGenBuffers(1, &buffers.vbo);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, buffers.vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, c.GL_STATIC_DRAW);

        // EBO
        const indices = [_]u32{ 0, 1, 2, 2, 3, 0 };
        c.glGenBuffers(1, &buffers.ebo);
        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, buffers.ebo);
        c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, c.GL_STATIC_DRAW);

        // Vertex Attributes
        const stride = 4 * @sizeOf(f32);
        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, stride, null);
        c.glEnableVertexAttribArray(1);
        c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, stride, @ptrFromInt(2 * @sizeOf(f32)));

        c.glBindVertexArray(0); // unbind for safety
        return buffers;
    }

    fn initUiBuffers(window_width: i32, window_height: i32) !UiRenderingBuffers {
        var buffers = UiRenderingBuffers{
            .vao = 0,
            .vbo = 0,
            .ebo = 0,
            .fbo = 0,
            .text_vbo = 0,
            .text_vao = 0,
            .texture = 0,
        };

        c.glGenVertexArrays(1, &buffers.vao);
        c.glBindVertexArray(buffers.vao);

        const vertices = [_]f32{
            // pos(x, y), uv(u,v)
            0.0, 0.0, 0.0, 0.0, // top-left
            1.0, 0.0, 1.0, 0.0, // top-right
            0.0, 1.0, 0.0, 1.0, // bottom-left
            1.0, 1.0, 1.0, 1.0, // bottom-right
        };

        const indices = [_]u32{ 0, 1, 2, 2, 3, 1 };

        c.glGenBuffers(1, &buffers.vbo);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, buffers.vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, c.GL_STATIC_DRAW);

        c.glGenBuffers(1, &buffers.ebo);
        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, buffers.ebo);
        c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, c.GL_STATIC_DRAW);

        const stride = 4 * @sizeOf(f32);
        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, stride, null);
        c.glEnableVertexAttribArray(1);
        c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, stride, @ptrFromInt(2 * @sizeOf(f32)));

        c.glBindVertexArray(0);

        // TEXT VAO
        c.glGenVertexArrays(1, &buffers.text_vao);
        c.glBindVertexArray(buffers.text_vao);

        // TEXT VBO
        c.glGenBuffers(1, &buffers.text_vbo);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, buffers.text_vbo);

        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, stride, null);
        c.glEnableVertexAttribArray(1);
        c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, stride, @ptrFromInt(2 * @sizeOf(f32)));

        c.glBindVertexArray(0);

        c.glGenFramebuffers(1, &buffers.fbo);
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, buffers.fbo);

        // create the texture that the FBO will render into
        c.glGenTextures(1, &buffers.texture);
        c.glBindTexture(c.GL_TEXTURE_2D, buffers.texture);

        // allocate empty image data
        c.glTexImage2D(
            c.GL_TEXTURE_2D,
            0, // mip level
            c.GL_RGBA, // internal format
            window_width,
            window_height,
            0,
            c.GL_RGBA,
            c.GL_UNSIGNED_BYTE,
            null,
        );

        // texture filtering
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);

        // attach the texture to the framebuffer as color attachment 0
        c.glFramebufferTexture2D(
            c.GL_FRAMEBUFFER,
            c.GL_COLOR_ATTACHMENT0,
            c.GL_TEXTURE_2D,
            buffers.texture,
            0,
        );

        // unbind framebuffer to avoid accidental use
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
        return buffers;
    }

    fn initCompositeBuffers() !CompositePassBuffers {
        var buffers = CompositePassBuffers{
            .vao = 0,
            .vbo = 0,
            .ebo = 0,
        };

        c.glGenVertexArrays(1, &buffers.vao);
        c.glBindVertexArray(buffers.vao);

        // VBO
        const vertices = [_]f32{
            -1.0, 1.0,  0.0, 1.0,
            -1.0, -1.0, 0.0, 0.0,
            1.0,  -1.0, 1.0, 0.0,
            1.0,  1.0,  1.0, 1.0,
        };
        c.glGenBuffers(1, &buffers.vbo);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, buffers.vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, c.GL_STATIC_DRAW);

        // EBO
        const indices = [_]u32{ 0, 1, 2, 2, 3, 0 };
        c.glGenBuffers(1, &buffers.ebo);
        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, buffers.ebo);
        c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, c.GL_STATIC_DRAW);

        // Vertex Attributes
        const stride = 4 * @sizeOf(f32);
        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, stride, null);
        c.glEnableVertexAttribArray(1);
        c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, stride, @ptrFromInt(2 * @sizeOf(f32)));

        c.glBindVertexArray(0); // unbind for safety
        return buffers;
    }

    pub fn resizeUIBuffers(self: *Gl, new_width: c.GLint, new_height: c.GLint) void {
        c.glBindTexture(c.GL_TEXTURE_2D, self.ui_buffers.texture);
        c.glTexImage2D(
            c.GL_TEXTURE_2D,
            0,
            c.GL_RGBA,
            new_width,
            new_height,
            0,
            c.GL_RGBA,
            c.GL_UNSIGNED_BYTE,
            null,
        );

        c.glBindFramebuffer(c.GL_FRAMEBUFFER, self.ui_buffers.fbo);
        c.glFramebufferTexture2D(
            c.GL_FRAMEBUFFER,
            c.GL_COLOR_ATTACHMENT0,
            c.GL_TEXTURE_2D,
            self.ui_buffers.texture,
            0,
        );
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
    }

    pub fn destroy(_: *Gl) void {}
};
