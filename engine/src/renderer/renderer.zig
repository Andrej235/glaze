const std = @import("std");

const App = @import("../app.zig").App;
const Gl = @import("gl/gl.zig").Gl;

const c = @cImport({
    @cInclude("../src/renderer/gl/glad/include/glad/gl.h");
});

const SpriteRenderer = @import("../components/sprite-renderer.zig").SpriteRenderer;
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
    width: u16 = 800,
    height: u16 = 600,
    title: [*:0]const u8 = "My Game",
};

pub const Renderer = struct {
    app: *App,
    window: *Window,
    initialized: bool = false,
    on_request_frame_event: *EventDispatcher(void, *anyopaque),
    material_cache: *TypeCache(std.heap.ArenaAllocator),

    fn onRequestFrame(_: void, data: ?*anyopaque) !void {
        const self = try Caster.castFromNullableAnyopaque(Renderer, data);
        _ = self.window.gl;

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
            const wrapper = obj.findComponentWrapperByType(SpriteRenderer);
            if (wrapper == null) continue;
            // std.debug.print("{s}", .{wrapper.?.component.getName()});

            const renderer = wrapper.?.getComponentAsType(SpriteRenderer);
            const material = renderer.getMaterial() catch {
                continue;
            };

            const program = material.program;

            const vertices = [_]f32{
                0.0,  0.5,
                -0.5, -0.5,
                0.5,  -0.5,
            };

            var vbo: c.GLuint = 0;
            c.glGenBuffers(1, &vbo);
            c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
            c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, c.GL_STATIC_DRAW);

            const pos_attr = c.glGetAttribLocation(program, "position");
            c.glUseProgram(program);
            c.glEnableVertexAttribArray(@intCast(pos_attr));
            c.glVertexAttribPointer(@intCast(pos_attr), 2, c.GL_FLOAT, c.GL_FALSE, 0, null);
        }

        c.glDrawArrays(c.GL_TRIANGLES, 0, 3);
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
