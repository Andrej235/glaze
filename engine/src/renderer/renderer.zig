const std = @import("std");

const GL = @import("gl.zig").GL;

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
    gl: *GL,

    fn on_request_frame(_: void, data: ?*anyopaque) !void {
        std.debug.print("on_request_frame\n", .{});
        const self = try Caster.castFromNullableAnyopaque(Renderer, data);
        const gl = self.gl;

        gl.glViewport(0, 0, self.window.width, self.window.height);
        gl.glClearColor(0.3, 0.0, 0.5, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        try self.window.gl_context.swap_buffers(self.window.gl_context);
    }

    pub fn init() !*Renderer {
        const allocator = std.heap.page_allocator;

        const window = try platform_renderer.init();

        const new_gl = try allocator.create(GL);
        new_gl.* = try GL.init(window.gl_context);

        const renderer = allocator.create(Renderer) catch unreachable;
        renderer.* = Renderer{
            .window = window,
            .gl = new_gl,
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
