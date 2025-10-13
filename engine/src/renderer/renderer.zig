const std = @import("std");

const App = @import("../app.zig").App;
const Gl = @import("gl/gl.zig").Gl;

const c = @cImport({
    @cInclude("../src/renderer/gl/glad/include/glad/gl.h");
});

const SpriteRenderer = @import("../components/sprite-renderer.zig").SpriteRenderer;
const Transform = @import("../components/transform.zig").Transform;

const EventDispatcher = @import("../event-system/event_dispatcher.zig").EventDispatcher;
const Caster = @import("../utils/caster.zig");
const Platform = @import("../utils/platform.zig");
const Window = @import("window.zig").Window;
const TypeCache = @import("../utils/type-cache.zig").TypeCache;
const allocateNewArena = @import("../utils/arena_allocator_util.zig").allocateNewArena;

const PlatformRenderer = VerifyPlatformRenderer(switch (Platform.current_platform) {
    .linux => @import("../platform/linux/linux.zig").Linux,
    .windows => @import("../platform/windows.zig"),
    else => @compileError("Unsupported platform"),
});

var renderer_instance: ?*Renderer = null;

const RendererOptions = struct {
    width: i32 = 800,
    height: i32 = 600,
    title: [*:0]const u8 = "My Game",
};

pub const Renderer = struct {
    app: *App,
    window: *Window,
    initialized: bool = false,
    on_request_frame_event: *EventDispatcher(void, *anyopaque),
    material_cache: *TypeCache(std.heap.ArenaAllocator),

    pub fn makeOrthoMatrix(width: f32, height: f32) [16]f32 {
        std.debug.print("{}x{}\n", .{ width, height });
        const half_w_units = (width / 100.0) / 2.0;
        const half_h_units = (height / 100.0) / 2.0;

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

        // Ignore errors to allow the render loop to run independently
        self.on_request_frame_event.dispatch({}) catch {};

        c.glViewport(0, 0, self.window.width, self.window.height);
        c.glClearColor(0.3, 0.0, 0.5, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        const scene = self.app.scene_manager.getActiveScene() catch {
            c.glDrawArrays(c.GL_TRIANGLES, 0, 3);
            try self.window.gl.context.swap_buffers(self.window.gl.context);
            return;
        };

        const game_objects = scene.game_objects;

        for (game_objects.items) |obj| {
            const transformWrapper = obj.findComponentWrapperByType(Transform);
            if (transformWrapper == null) continue;

            const rendererWrapper = obj.findComponentWrapperByType(SpriteRenderer);
            if (rendererWrapper == null) continue;
            // std.debug.print("{s}", .{wrapper.?.component.getName()});

            const transform = transformWrapper.?.getComponentAsType(Transform);
            const renderer = rendererWrapper.?.getComponentAsType(SpriteRenderer);

            const material = renderer.getMaterial() catch continue;
            const program = material.program;

            const vertices = [_]f32{
                // x, y, u, v
                -0.5, 0.5, 0.0, 1.0, // top-left
                -0.5, -0.5, 0.0, 0.0, // bottom-left
                0.5, -0.5, 1.0, 0.0, // bottom-right
                0.5, 0.5, 1.0, 1.0, // top-right
            };

            const indices = [_]u32{
                0, 1, 2, // first triangle
                2, 3, 0, // second triangle
            };

            var vbo: c.GLuint = 0;
            c.glGenBuffers(1, &vbo);
            c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
            c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, c.GL_STATIC_DRAW);

            var ebo: c.GLuint = 0;
            c.glGenBuffers(1, &ebo);
            c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
            c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, c.GL_STATIC_DRAW);

            c.glUseProgram(program);

            const stride = 4 * @sizeOf(f32);
            const pos_attr = c.glGetAttribLocation(program, "a_Position");
            const tex_attr = c.glGetAttribLocation(program, "a_TexCoord");

            c.glEnableVertexAttribArray(@intCast(pos_attr));
            c.glVertexAttribPointer(@intCast(pos_attr), 2, c.GL_FLOAT, c.GL_FALSE, stride, null);

            c.glEnableVertexAttribArray(@intCast(tex_attr));
            c.glVertexAttribPointer(@intCast(tex_attr), 2, c.GL_FLOAT, c.GL_FALSE, stride, @ptrFromInt(@sizeOf(f32) * 2));

            // model matrix
            const model_matrix = transform.get2DMatrix();
            const model_loc = c.glGetUniformLocation(program, "u_Model");
            c.glUniformMatrix4fv(model_loc, 1, c.GL_FALSE, &model_matrix);

            // projection matrix
            const proj = makeOrthoMatrix(@floatFromInt(self.window.width), @floatFromInt(self.window.height));
            const proj_loc = c.glGetUniformLocation(program, "u_Projection");
            c.glUniformMatrix4fv(proj_loc, 1, c.GL_FALSE, &proj);

            c.glDrawElements(c.GL_TRIANGLES, 6, c.GL_UNSIGNED_INT, null);
        }

        try self.window.gl.context.swap_buffers(self.window.gl.context);
    }

    pub fn subscribeToRequestFrameEvent(callback: *const fn (void, ?*anyopaque) anyerror!void, data: ?*anyopaque) !void {
        if (renderer_instance == null)
            return error.RendererNotInitialized;

        try renderer_instance.?.on_request_frame_event.addHandler(callback, data);
    }

    pub fn cacheMaterial(TMaterial: type) !*TMaterial {
        if (renderer_instance == null)
            return error.RendererNotInitialized;

        return renderer_instance.?.material_cache.getOrCreate(TMaterial, TMaterial.create);
    }

    // DO NOT USE GL IN HERE IT IS EXECUTED ON THE MAIN FUCKING THREAD
    pub fn init(options: RendererOptions) !*Renderer {
        const app = App.get();

        var allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        const window = try PlatformRenderer.init(options);

        const renderer = allocator.allocator().create(Renderer) catch unreachable;
        const event = try EventDispatcher(void, *anyopaque).create();

        const material_cache_arena = try allocateNewArena();
        const material_cache = try material_cache_arena.allocator().create(TypeCache(std.heap.ArenaAllocator));
        material_cache.* = TypeCache(std.heap.ArenaAllocator).init(material_cache_arena);

        renderer.* = Renderer{
            .window = window,
            .on_request_frame_event = event,
            .material_cache = material_cache,
            .app = app,
        };

        try window.on_request_frame.addHandler(onRequestFrame, renderer);
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
