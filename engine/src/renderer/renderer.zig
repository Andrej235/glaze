const std = @import("std");

const Debug = @import("../debug/debug.zig").Debug;

const App = @import("../app.zig").App;
const Gl = @import("gl/gl.zig").Gl;

const c = @cImport({
    @cInclude("../src/renderer/gl/glad/include/glad/gl.h");
});

const RendererOptions = @import("renderer-options.zig").RendererOptions;

const TextureManager = @import("../textures/texture-manager.zig").TextureManager;

const SpriteRenderer = @import("../components/sprite-renderer.zig").SpriteRenderer;
const Transform = @import("../components/transform.zig").Transform;
const Camera2D = @import("../components/camera.zig").Camera2D;

const CompositeMaterial = @import("../materials/composite-material.zig").CompositeMaterial;

const EventDispatcher = @import("../event-system/event-dispatcher.zig").EventDispatcher;
const Caster = @import("../utils/caster.zig");
const Platform = @import("../utils/platform.zig");
const Window = @import("window.zig").Window;
const TypeCache = @import("../utils/type-cache.zig").TypeCache;
const allocateNewArena = @import("../utils/arena-allocator-util.zig").allocateNewArena;

const UINode = @import("../ui/ui-node.zig").UINode;
const UIElement = @import("../ui/ui-element.zig").UIElement;

const PlatformRenderer = VerifyPlatformRenderer(switch (Platform.current_platform) {
    .linux => @import("../platform/linux/linux.zig").Linux,
    .windows => @import("../platform/windows.zig").Windows,
    else => @compileError("Unsupported platform"),
});

var renderer_instance: ?*Renderer = null;

pub const Renderer = struct {
    app: *App,
    window: *Window,

    scene_vbo_handle: c.GLuint = undefined,
    scene_ebo_handle: c.GLuint = undefined,
    scene_vao_handle: c.GLuint = undefined,
    are_scene_buffers_initialized: bool = false,

    ui_fbo_handle: c.GLuint = undefined,
    ui_vbo_handle: c.GLuint = undefined,
    ui_ebo_handle: c.GLuint = undefined,
    ui_vao_handle: c.GLuint = undefined,
    ui_texture_handle: c.GLuint = undefined,
    are_ui_buffers_initialized: bool = false,

    material_cache: *TypeCache(std.heap.ArenaAllocator),
    texture_manager: TextureManager,

    const pixels_per_unit = 100.0;

    pub fn makeOrthoProjectionMatrix(width: f32, height: f32) [16]f32 {
        // 1 unit = 100 px
        const half_w_units = (width / pixels_per_unit) / 2.0;
        const half_h_units = (height / pixels_per_unit) / 2.0;

        const left = -half_w_units;
        const right = half_w_units;
        const bottom = -half_h_units;
        const top = half_h_units;
        const near = -1.0;
        const far = 1.0;

        return .{
            2.0 / (right - left),             0.0,                              0.0,                          0.0,
            0.0,                              2.0 / (top - bottom),             0.0,                          0.0,
            0.0,                              0.0,                              -2.0 / (far - near),          0.0,
            -(right + left) / (right - left), -(top + bottom) / (top - bottom), -(far + near) / (far - near), 1.0,
        };
    }

    fn onRequestFrame(_: void, data: ?*anyopaque) !void {
        const self = try Caster.castFromNullableAnyopaque(Renderer, data);

        try self.renderScene();
        try self.renderUI();
        try self.compositePass();
        try self.window.gl.context.swap_buffers(self.window.gl.context);
    }

    inline fn renderScene(self: *Renderer) !void {
        const scene = self.app.scene_manager.getActiveScene() catch return;

        if (scene.camera) |cameraObj| {
            var last_used_material_program: u32 = 0;
            var last_used_texture: u32 = 0;
            var last_used_window_width: i32 = 0;
            var last_used_window_height: i32 = 0;

            // initialize buffers only once
            if (!self.are_scene_buffers_initialized) {
                var vao: c.GLuint = 0;
                c.glGenVertexArrays(1, &vao);
                self.scene_vao_handle = vao;
                c.glBindVertexArray(self.scene_vao_handle);

                // VBO
                const vertices = [_]f32{
                    -0.5, 0.5,  0.0, 1.0,
                    -0.5, -0.5, 0.0, 0.0,
                    0.5,  -0.5, 1.0, 0.0,
                    0.5,  0.5,  1.0, 1.0,
                };
                c.glGenBuffers(1, &self.scene_vbo_handle);
                c.glBindBuffer(c.GL_ARRAY_BUFFER, self.scene_vbo_handle);
                c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, c.GL_STATIC_DRAW);

                // EBO
                const indices = [_]u32{ 0, 1, 2, 2, 3, 0 };
                c.glGenBuffers(1, &self.scene_ebo_handle);
                c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, self.scene_ebo_handle);
                c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, c.GL_STATIC_DRAW);

                // Vertex Attributes
                const stride = 4 * @sizeOf(f32);
                c.glEnableVertexAttribArray(0);
                c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, stride, null);
                c.glEnableVertexAttribArray(1);
                c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, stride, @ptrFromInt(2 * @sizeOf(f32)));

                c.glBindVertexArray(0); // unbind for safety
                self.are_scene_buffers_initialized = true;
            }

            c.glBindVertexArray(self.scene_vao_handle);

            c.glViewport(0, 0, self.window.width, self.window.height);
            c.glClearColor(0.3, 0.0, 0.5, 1.0);
            c.glClear(c.GL_COLOR_BUFFER_BIT);

            const spatial_hash = scene.spatial_hash;

            try spatial_hash.registerGameObjects(spatial_hash.instance);

            const proj_matrix = makeOrthoProjectionMatrix(@floatFromInt(self.window.width), @floatFromInt(self.window.height));

            const camera = cameraObj.getComponent(Camera2D) orelse return error.InvalidCamera;
            const view_matrix = camera.makeViewMatrix();

            const camera_cell_range = try spatial_hash.get_camera_cell_range(
                spatial_hash.instance,
                camera,
                @as(f32, @floatFromInt(self.window.width)) / pixels_per_unit,
                @as(f32, @floatFromInt(self.window.height)) / pixels_per_unit,
            );

            for (camera_cell_range.y0..camera_cell_range.y1 + 1) |y| {
                for (camera_cell_range.x0..camera_cell_range.x1 + 1) |x| {
                    const bucket = spatial_hash.cells + (y * spatial_hash.grid_width + x);

                    for (bucket[0].items) |obj| {
                        const transform = obj.getComponent(Transform) orelse continue;
                        const renderer = obj.getComponent(SpriteRenderer("")) orelse continue;

                        const material = try renderer.getMaterial();

                        if (material.program != last_used_material_program) {
                            c.glUseProgram(material.program);
                        }

                        if (material.program != last_used_material_program or last_used_window_width != self.window.width or last_used_window_height != self.window.height) {
                            c.glUniformMatrix4fv(material.view_matrix_uniform_location, 1, c.GL_FALSE, &view_matrix);
                            c.glUniformMatrix4fv(material.projection_matrix_uniform_location, 1, c.GL_FALSE, &proj_matrix);

                            last_used_window_width = self.window.width;
                            last_used_window_height = self.window.height;
                        }

                        // bind texture
                        if (renderer.getSpriteTexture()) |tex| {
                            if (last_used_texture != tex or last_used_material_program != material.program) {
                                c.glActiveTexture(c.GL_TEXTURE0);
                                c.glBindTexture(c.GL_TEXTURE_2D, tex);
                                c.glUniform1i(material.texture_uniform_location, 0);
                                last_used_texture = tex;
                            }
                        }

                        last_used_material_program = material.program;

                        // bind model matrix, this is the only one that needs to be bound for each object individually
                        const model_matrix = transform.get2DMatrix();
                        c.glUniformMatrix4fv(material.model_matrix_uniform_location, 1, c.GL_FALSE, &model_matrix);

                        c.glUniform4fv(material.color_uniform_location, 1, renderer.color);
                        c.glDrawElements(c.GL_TRIANGLES, 6, c.GL_UNSIGNED_INT, null);
                    }
                }
            }
        }
    }

    inline fn renderUI(self: *Renderer) !void {
        const scene = self.app.scene_manager.getActiveScene() catch return;
        const root = scene.ui_root orelse return;

        // initialize buffers only once
        if (!self.are_ui_buffers_initialized) {
            var vao: c.GLuint = 0;
            c.glGenVertexArrays(1, &vao);
            self.ui_vao_handle = vao;
            c.glBindVertexArray(self.ui_vao_handle);

            const vertices = [_]f32{
                // full-screen quad (clip space coords)
                -1.0, -1.0, 0.0, 0.0,
                1.0,  -1.0, 1.0, 0.0,
                -1.0, 1.0,  0.0, 1.0,
                1.0,  1.0,  1.0, 1.0,
            };
            const indices = [_]u32{ 0, 1, 2, 2, 3, 1 };

            c.glGenBuffers(1, &self.ui_vbo_handle);
            c.glBindBuffer(c.GL_ARRAY_BUFFER, self.ui_vbo_handle);
            c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, c.GL_STATIC_DRAW);

            c.glGenBuffers(1, &self.ui_ebo_handle);
            c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, self.ui_ebo_handle);
            c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, c.GL_STATIC_DRAW);

            const stride = 4 * @sizeOf(f32);
            c.glEnableVertexAttribArray(0);
            c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, stride, null);
            c.glEnableVertexAttribArray(1);
            c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, stride, @ptrFromInt(2 * @sizeOf(f32)));

            c.glBindVertexArray(0);

            var fbo: c.GLuint = 0;
            c.glGenFramebuffers(1, &fbo);
            self.ui_fbo_handle = fbo;
            c.glBindFramebuffer(c.GL_FRAMEBUFFER, self.ui_fbo_handle);

            // create the texture that the FBO will render into
            var tex: c.GLuint = 0;
            c.glGenTextures(1, &tex);
            self.ui_texture_handle = tex;
            c.glBindTexture(c.GL_TEXTURE_2D, tex);

            // allocate empty image data
            c.glTexImage2D(
                c.GL_TEXTURE_2D,
                0, // mip level
                c.GL_RGBA, // internal format
                self.window.width,
                self.window.height,
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
                self.ui_texture_handle,
                0,
            );

            // unbind framebuffer to avoid accidental use
            c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
            self.are_ui_buffers_initialized = true;
        }

        c.glBindFramebuffer(c.GL_FRAMEBUFFER, self.ui_fbo_handle);
        c.glViewport(0, 0, self.window.width, self.window.height);
        c.glDisable(c.GL_DEPTH_TEST);
        c.glClearColor(0, 0, 0, 0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        c.glBindVertexArray(self.ui_vao_handle);

        var last_used_material_program: c.GLuint = 0;
        try self.renderUINode(root, &last_used_material_program);

        c.glBindVertexArray(0);
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
    }

    fn renderUINode(self: *Renderer, node: *UINode, last_used_material_program: *c.GLuint) !void {
        switch (node.*) {
            .text => {},
            .element => |element| {
                const material = try element.getMaterial();

                if (material.program != last_used_material_program.*) {
                    c.glUseProgram(material.program);

                    const view_matrix: [16]f32 = .{
                        1, 0, 0, 0,
                        0, 1, 0, 0,
                        0, 0, 1, 0,
                        0, 0, 0, 1,
                    };
                    const proj_matrix = makeOrthoProjectionMatrix(@floatFromInt(self.window.width), @floatFromInt(self.window.height));

                    c.glUniformMatrix4fv(material.view_matrix_uniform_location, 1, c.GL_FALSE, &view_matrix);
                    c.glUniformMatrix4fv(material.projection_matrix_uniform_location, 1, c.GL_FALSE, &proj_matrix);
                }

                last_used_material_program.* = material.program;

                // bind model matrix, this is the only one that needs to be bound for each object individually
                const model_matrix = element.makeModelMatrix(0, 0, 250, 250);
                c.glUniformMatrix4fv(material.model_matrix_uniform_location, 1, c.GL_FALSE, &model_matrix);

                var color = [4]f32{ 1, 1, 1, 1 };
                c.glUniform4fv(material.color_uniform_location, 1, &color);
                c.glDrawElements(c.GL_TRIANGLES, 6, c.GL_UNSIGNED_INT, null);

                for (element.children.items) |*child| {
                    try self.renderUINode(child, last_used_material_program);
                }
            },
        }
    }

    inline fn compositePass(self: *Renderer) !void {
        const comp_material = try cacheMaterial(CompositeMaterial);
        const material = comp_material.material;

        c.glUseProgram(material.program);
        c.glActiveTexture(c.GL_TEXTURE0);
        c.glBindTexture(c.GL_TEXTURE_2D, self.ui_texture_handle);
        c.glUniform1i(material.texture_uniform_location, 0);
    }

    pub fn cacheMaterial(TMaterial: type) !*TMaterial {
        if (renderer_instance == null)
            return error.RendererNotInitialized;

        return renderer_instance.?.material_cache.getOrCreate(TMaterial, TMaterial.create);
    }

    pub fn cacheTexture(path: []const u8) !c.GLuint {
        if (renderer_instance == null)
            return error.RendererNotInitialized;

        return try renderer_instance.?.texture_manager.getOrLoad(path);
    }

    // DO NOT USE GL IN HERE IT IS EXECUTED ON THE MAIN FUCKING THREAD
    pub fn init(options: RendererOptions) !*Renderer {
        const app = App.get();

        var allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        const window = try PlatformRenderer.init(options);

        const renderer = allocator.allocator().create(Renderer) catch unreachable;

        const material_cache_arena = try allocateNewArena();
        const material_cache = try material_cache_arena.allocator().create(TypeCache(std.heap.ArenaAllocator));
        material_cache.* = TypeCache(std.heap.ArenaAllocator).init(material_cache_arena);

        renderer.* = Renderer{
            .app = app,
            .window = window,
            .material_cache = material_cache,
            .texture_manager = TextureManager.init(),
        };

        _ = try window.on_request_frame.addHandler(onRequestFrame, renderer);
        renderer_instance = renderer;
        return renderer;
    }

    pub fn deinit(self: *Renderer) void {
        self.window.deinit();
    }
};

fn VerifyPlatformRenderer(comptime renderer: type) type {
    if (!@hasDecl(renderer, "initWindow"))
        @compileError("Platform implementation missing initWindow()");

    const fn_info = @typeInfo(@TypeOf(renderer.initWindow)).@"fn";
    if (fn_info.return_type != anyerror!*Window)
        @compileError("Platform implementation's initWindow() has incorrect return type");

    return struct {
        pub fn init(options: RendererOptions) !*Window {
            return renderer.initWindow(options.width, options.height, options.title);
        }
    };
}
