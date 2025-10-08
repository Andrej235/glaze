const std = @import("std");

const Caster = @import("../utils/caster.zig");
const Platform = @import("../utils/platform.zig");
const Window = @import("window.zig").Window;

const platform_renderer = verify_platform_renderer(switch (Platform.current_platform) {
    .linux => @import("../platform/linux/linux.zig").Linux,
    .windows => @import("../platform/windows.zig"),
    else => @compileError("Unsupported platform"),
});

const c = @cImport({
    @cInclude("wayland-client.h");
    @cInclude("wayland-egl.h");
    @cInclude("EGL/egl.h");
    @cInclude("GLES2/gl2.h");
    @cInclude("xkbcommon/xkbcommon.h");
    @cInclude("platform/linux//xdg-shell-client-protocol.h");
});

pub const Renderer = struct {
    window: *Window,
    program: c.GLuint = 0,

    fn on_request_frame(_: void, data: ?*anyopaque) !void {
        const self = try Caster.castFromNullableAnyopaque(Renderer, data);

        c.glViewport(0, 0, self.window.width, self.window.height);
        c.glClearColor(1, 0.1, 0.1, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        // c.glUseProgram(inner_inner_self.program);
        // c.glUniform1f(c.glGetUniformLocation(inner_inner_self.program, "angle"), 0);

        c.glEnableVertexAttribArray(0);
        const verts: [12]c.GLfloat = [12]c.GLfloat{ -0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, -0.5, 0.5, 0.5, -0.5, 0.5 };
        c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, 0, &verts[0]);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 6);
        c.glDisableVertexAttribArray(0);

        // c.glViewport(0, 0, self.window.width, self.window.height);
        // c.glClearColor(1.0, 0.0, 0.0, 1.0); // bright red
        // c.glClear(c.GL_COLOR_BUFFER_BIT);

        // check errors and swap result
        // const err: c.GLenum = c.glGetError();
        // if (err != 0) std.debug.print("glClear glError: 0x{x}\n", .{err});
        try self.window.gl_context.swap_buffers(self.window.gl_context);
    }

    pub fn init() !*Renderer {
        const allocator = std.heap.page_allocator;

        const window = try platform_renderer.init();
        const renderer = allocator.create(Renderer) catch unreachable;
        renderer.* = Renderer{
            .window = window,
        };

        try window.on_request_frame.addHandler(on_request_frame, renderer);

        return renderer;
    }

    pub fn deinit(self: *Renderer) void {
        self.window.deinit();
    }
};

fn verify_platform_renderer(comptime renderer: type) type {
    if (!@hasDecl(renderer, "init_window"))
        @compileError("Platform implementation missing init_window()");

    const fn_info = @typeInfo(@TypeOf(renderer.init_window)).@"fn";
    if (fn_info.return_type != anyerror!*Window)
        @compileError("Platform implementation's init_window() has incorrect return type");

    return struct {
        pub fn init() !*Window {
            return renderer.init_window();
        }
    };
}
