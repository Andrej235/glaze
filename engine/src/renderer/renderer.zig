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

const PlatformRenderer = PlatformRendererImplementation(switch (Platform.current_platform) {
    .linux => @import("../platform/linux/linux.zig").Linux,
    .windows => @import("../platform/windows.zig").Windows,
    else => @compileError("Unsupported platform"),
});

var renderer_instance: ?*Renderer = null;

pub const Renderer = struct {
    app: *App,
    window: *Window,

    material_cache: *TypeCache(std.heap.ArenaAllocator),
    texture_manager: TextureManager,

    ui_window_width: i32 = 0,
    ui_window_height: i32 = 0,

    const pixels_per_unit = 100.0;

    pub fn makeWorldOrthoProjectionMatrix(width: f32, height: f32) [16]f32 {
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

    pub fn makeTextOrthoProjectionMatrix(left: f32, right: f32, top: f32, bottom: f32) [16]f32 {
        return .{
            2.0 / (right - left),             0,                                0,  0,
            0,                                2.0 / (bottom - top),             0,  0,
            0,                                0,                                -1, 0,
            -(right + left) / (right - left), -(bottom + top) / (bottom - top), 0,  1,
        };
    }

    pub fn makeOrthoProjection(width: f32, height: f32) [16]f32 {
        const rw = 2.0 / width;
        const rh = -2.0 / height; // negative to flip Y so 0=top
        return .{
            rw, 0,  0,  0,
            0,  rh, 0,  0,
            0,  0,  -1, 0,
            -1, 1,  0,  1,
        };
    }

    fn onRequestFrame(_: void, data: ?*anyopaque) !void {
        const self = try Caster.castFromNullableAnyopaque(Renderer, data);

        try self.renderScene();
        try self.renderUI();
        try self.compositePass();
        try self.window.gl.context.swapBuffers(self.window.gl.context);
    }

    inline fn renderScene(self: *Renderer) !void {
        const scene = self.app.scene_manager.getActiveScene() catch return;
        const cameraObj = scene.camera orelse return;

        var last_used_material_program: u32 = 0;
        var last_used_texture: u32 = 0;

        c.glBindVertexArray(self.window.gl.scene_buffers.vao);

        c.glViewport(0, 0, self.window.width, self.window.height);
        c.glClearColor(0.3, 0.0, 0.5, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        const spatial_hash = scene.spatial_hash;

        try spatial_hash.registerGameObjects(spatial_hash.instance);

        const proj_matrix = makeWorldOrthoProjectionMatrix(@floatFromInt(self.window.width), @floatFromInt(self.window.height));

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

                        c.glUniformMatrix4fv(material.view_matrix_uniform_location, 1, c.GL_FALSE, &view_matrix);
                        c.glUniformMatrix4fv(material.projection_matrix_uniform_location, 1, c.GL_FALSE, &proj_matrix);
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

    inline fn renderUI(self: *Renderer) !void {
        const scene = self.app.scene_manager.getActiveScene() catch return;
        const root = scene.ui_root orelse return;

        root.element.makeDirty();
        var unresolved: bool = false; // unresolved is set to true if one of the elements requires more passes
        try root.element.resolveTree(&unresolved);

        while (unresolved) {
            unresolved = false;
            try root.element.resolveTree(&unresolved);
        }

        // resize UI buffers if needed (texture needs to be recreated)
        if (self.ui_window_height != self.window.height or self.ui_window_width != self.window.width) {
            self.window.gl.resizeUIBuffers(self.window.width, self.window.height);
            self.ui_window_width = self.window.width;
            self.ui_window_height = self.window.height;
        }

        c.glBindFramebuffer(c.GL_FRAMEBUFFER, self.window.gl.ui_buffers.fbo);
        c.glViewport(0, 0, self.window.width, self.window.height);
        c.glDisable(c.GL_DEPTH_TEST);
        c.glClearColor(0, 0, 1, 0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        var last_used_material_program: c.GLuint = 0;
        try self.renderUINode(root, &last_used_material_program);

        c.glBindVertexArray(0);
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
    }

    fn renderUINode(self: *Renderer, node: *UINode, last_used_material_program: *c.GLuint) !void {
        switch (node.*) {
            .text => |text| {
                const font = text.font;

                const font_size_px: f32 = 64.0;
                const scale = font_size_px / font.metadata.metrics.emSize;
                var total: f64 = 0;

                for (text.text) |char| {
                    if (font.getGlyph(char)) |glyph| {
                        total += glyph.advance * scale;
                    }
                }

                var pen_x: f64 = 0;
                var text_start_y: f64 = 0;

                if (text.parent) |parent| {
                    pen_x = parent.resolved_left;
                    text_start_y = parent.resolved_top;
                }

                const ascender = font.metadata.metrics.ascender;
                const baseline_y = text_start_y + ascender * scale;

                const verts: []f32 = try std.heap.c_allocator.alloc(f32, 6 * 4 * text.text.len); // 6 verts per letter, each vert has 4 floats (x, y, u, v)
                defer std.heap.c_allocator.free(verts);
                var i: usize = 0;

                for (text.text) |char| {
                    if (font.getGlyph(char)) |glyph| {
                        if (glyph.planeBounds) |bounds| {
                            const gw = (bounds.right - bounds.left) * scale;
                            const gh = (bounds.top - bounds.bottom) * scale;

                            const gx = pen_x + bounds.left * scale;
                            const gy = baseline_y - bounds.top * scale;

                            // Normalized Device Coordinates
                            const x0 = (gx / @as(f64, @floatFromInt(self.window.width))) * 2 - 1;
                            const y0 = 1 - (gy / @as(f64, @floatFromInt(self.window.height))) * 2;
                            const x1 = ((gx + gw) / @as(f64, @floatFromInt(self.window.width))) * 2 - 1;
                            const y1 = 1 - ((gy + gh) / @as(f64, @floatFromInt(self.window.height))) * 2;

                            const atlasW: f64 = @floatFromInt(font.metadata.atlas.width);
                            const atlasH: f64 = @floatFromInt(font.metadata.atlas.height);

                            const left = glyph.atlasBounds.?.left;
                            const right = glyph.atlasBounds.?.right;
                            const top = glyph.atlasBounds.?.top;
                            const bottom = glyph.atlasBounds.?.bottom;

                            const uv_u0 = left / atlasW;
                            const uv_u1 = right / atlasW;
                            const uv_v0 = 1 - (top / atlasH);
                            const uv_v1 = 1 - (bottom / atlasH);

                            push(verts, &i, x0, y0, uv_u0, uv_v0);
                            push(verts, &i, x0, y1, uv_u0, uv_v1);
                            push(verts, &i, x1, y1, uv_u1, uv_v1);

                            push(verts, &i, x0, y0, uv_u0, uv_v0);
                            push(verts, &i, x1, y1, uv_u1, uv_v1);
                            push(verts, &i, x1, y0, uv_u1, uv_v0);

                            pen_x += glyph.advance * scale;
                        } else {
                            pen_x += glyph.advance * scale;
                        }
                    }
                }

                const material = try text.getMaterial();
                c.glBindVertexArray(self.window.gl.ui_buffers.text_vao);
                c.glBindBuffer(c.GL_ARRAY_BUFFER, self.window.gl.ui_buffers.text_vbo);
                c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(i * @sizeOf(f32)), verts.ptr, c.GL_DYNAMIC_DRAW);

                if (material.program != last_used_material_program.*) {
                    c.glUseProgram(material.program);

                    const proj_matrix = makeTextOrthoProjectionMatrix(-1, 1, -1, 1);
                    c.glUniformMatrix4fv(material.projection_matrix_uniform_location, 1, c.GL_FALSE, &proj_matrix);

                    c.glUniform1f(material.pixel_range_uniform_location, @floatCast(font.metadata.atlas.distanceRange));
                }

                last_used_material_program.* = material.program;

                var color = [4]f32{ 1, 1, 1, 1 };
                c.glUniform4fv(material.color_uniform_location, 1, &color);

                c.glActiveTexture(c.GL_TEXTURE0);
                const atlas = try font.getAtlasTexture();
                c.glBindTexture(c.GL_TEXTURE_2D, atlas);
                c.glUniform1i(material.texture_uniform_location, 0);

                const vert_count: c.GLint = @intCast(i / 4);
                c.glDrawArrays(c.GL_TRIANGLES, 0, vert_count);
            },
            .element => |element| {
                c.glBindVertexArray(self.window.gl.ui_buffers.vao);
                const material = try element.getMaterial();

                if (material.program != last_used_material_program.*) {
                    c.glUseProgram(material.program);

                    const view_matrix: [16]f32 = .{
                        1, 0, 0, 0,
                        0, 1, 0, 0,
                        0, 0, 1, 0,
                        0, 0, 0, 1,
                    };
                    const proj_matrix = makeOrthoProjection(
                        @floatFromInt(self.window.width),
                        @floatFromInt(self.window.height),
                    );

                    c.glUniformMatrix4fv(material.view_matrix_uniform_location, 1, c.GL_FALSE, &view_matrix);
                    c.glUniformMatrix4fv(material.projection_matrix_uniform_location, 1, c.GL_FALSE, &proj_matrix);
                }

                last_used_material_program.* = material.program;

                // bind model matrix, this is the only one that needs to be bound for each object individually
                const model_matrix = element.makeModelMatrix();
                c.glUniformMatrix4fv(material.model_matrix_uniform_location, 1, c.GL_FALSE, &model_matrix);

                c.glUniform4fv(material.color_uniform_location, 1, &element.background_color);
                c.glDrawElements(c.GL_TRIANGLES, 6, c.GL_UNSIGNED_INT, null);

                for (element.children.items) |child| {
                    try self.renderUINode(child, last_used_material_program);
                }
            },
        }
    }

    inline fn push(verts: []f32, i: *usize, x: f64, y: f64, u: f64, v: f64) void {
        verts[i.*] = @floatCast(x);
        verts[i.* + 1] = @floatCast(y);
        verts[i.* + 2] = @floatCast(u);
        verts[i.* + 3] = @floatCast(v);
        i.* += 4;
    }

    inline fn compositePass(self: *Renderer) !void {
        const comp_material = try cacheMaterial(CompositeMaterial);
        const material = comp_material.material;

        if (self.window.gl.ui_buffers.texture == 0) {
            std.debug.print("compositePass: missing tex handle", .{});
            return;
        }

        // shader + texture
        c.glUseProgram(material.program);
        c.glActiveTexture(c.GL_TEXTURE0);
        c.glBindTexture(c.GL_TEXTURE_2D, self.window.gl.ui_buffers.texture);
        c.glUniform1i(material.texture_uniform_location, 0);
        c.glBindVertexArray(0);

        c.glBindVertexArray(self.window.gl.composite_buffers.vao);
        c.glDrawElements(c.GL_TRIANGLES, 6, c.GL_UNSIGNED_INT, null);

        c.glBindVertexArray(0);
        c.glBindTexture(c.GL_TEXTURE_2D, 0);
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

    pub fn cacheAtlasTexture(path: []const u8) !c.GLuint {
        if (renderer_instance == null)
            return error.RendererNotInitialized;

        return try renderer_instance.?.texture_manager.getOrLoadAtlas(path);
    }

    pub fn getWindow() !*Window {
        if (renderer_instance) |renderer|
            return renderer.window;

        return error.RendererNotInitialized;
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

fn PlatformRendererImplementation(comptime renderer: type) type {
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
