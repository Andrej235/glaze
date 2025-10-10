const std = @import("std");

const Gl = @import("gl/gl.zig").Gl;

const c = @cImport({
    @cInclude("../src/renderer/gl/glad/include/glad/gl.h");
});

const EventDispatcher = @import("../event-system/event_dispatcher.zig").EventDispatcher;
const Caster = @import("../utils/caster.zig");
const Platform = @import("../utils/platform.zig");
const Window = @import("window.zig").Window;

const PlatformRenderer = VerifyPlatformRenderer(switch (Platform.current_platform) {
    .linux => @import("../platform/linux/linux.zig").Linux,
    .windows => @import("../platform/windows.zig"),
    else => @compileError("Unsupported platform"),
});

var renderer_instance: ?*Renderer = null;

pub const Renderer = struct {
    window: *Window,
    initialized: bool = false,
    on_request_frame_event: *EventDispatcher(void),

    fn onRequestFrame(_: void, data: ?*anyopaque) !void {
        const self = try Caster.castFromNullableAnyopaque(Renderer, data);
        _ = self.window.gl;

        // Ignore errors to allow the render loop to run independently
        self.on_request_frame_event.dispatch({}) catch {};

        c.glViewport(0, 0, self.window.width, self.window.height);
        c.glClearColor(0.3, 0.0, 0.5, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        const program = createTriangleProgram();

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

        c.glDrawArrays(c.GL_TRIANGLES, 0, 3);

        try self.window.gl.context.swap_buffers(self.window.gl.context);
    }

    fn compileShader(source: [*:0]const u8, shader_type: c.GLenum) c.GLuint {
        const shader = c.glCreateShader(shader_type);
        c.glShaderSource(shader, 1, &source, null);
        c.glCompileShader(shader);

        var success: c.GLint = 0;
        c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &success);
        if (success == 0) {
            var info_log: [512]u8 = undefined;
            c.glGetShaderInfoLog(shader, 512, null, &info_log);
            std.debug.print("Shader compile error: {s}\n", .{info_log[0..]});
        }

        return shader;
    }

    fn createTriangleProgram() c.GLuint {
        const vert_src =
            \\#version 100
            \\attribute vec2 position;
            \\void main() {
            \\    gl_Position = vec4(position, 0.0, 1.0);
            \\}
        ;
        const frag_src =
            \\#version 100
            \\precision mediump float;
            \\void main() {
            \\    gl_FragColor = vec4(1.0, 0.5, 0.2, 1.0);
            \\}
        ;

        const vert = compileShader(vert_src, c.GL_VERTEX_SHADER);
        const frag = compileShader(frag_src, c.GL_FRAGMENT_SHADER);
        const program = c.glCreateProgram();
        c.glAttachShader(program, vert);
        c.glAttachShader(program, frag);
        c.glLinkProgram(program);

        var success: c.GLint = 0;
        c.glGetProgramiv(program, c.GL_LINK_STATUS, &success);
        if (success == 0) {
            var info_log: [512]u8 = undefined;
            c.glGetProgramInfoLog(program, 512, null, &info_log);
            std.debug.print("Program link error: {s}\n", .{info_log[0..]});
        }

        c.glDeleteShader(vert);
        c.glDeleteShader(frag);

        return program;
    }

    pub fn subscribeToRequestFrameEvent(callback: *const fn (void, ?*anyopaque) anyerror!void, data: ?*anyopaque) !void {
        if (renderer_instance == null)
            return error.RendererNotInitialized;

        try renderer_instance.?.on_request_frame_event.addHandler(callback, data);
    }

    // DO NOT USE GL IN HERE IT IS EXECUTED ON THE MAIN FUCKING THREAD
    pub fn init() !*Renderer {
        var allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        const window = try PlatformRenderer.init();

        const renderer = allocator.allocator().create(Renderer) catch unreachable;
        const event = try allocator.allocator().create(EventDispatcher(void));
        event.* = try EventDispatcher(void).init(&allocator);

        renderer.* = Renderer{
            .window = window,
            .on_request_frame_event = event,
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
        pub fn init() !*Window {
            return renderer.initWindow();
        }
    };
}
