const std = @import("std");

const c = @cImport({
    @cInclude("wayland-client.h");
    @cInclude("wayland-egl.h");
    @cInclude("EGL/egl.h");
    @cInclude("GLES2/gl2.h");
    @cInclude("xkbcommon/xkbcommon.h");
    @cInclude("wayland/xdg-shell-client-protocol.h");
});

pub const WaylandClient = struct {
    // Global variables
    var display: ?*c.wl_display = null;
    var registry: ?*c.wl_registry = null;
    var compositor: ?*c.wl_compositor = null;
    var wm_base: ?*c.xdg_wm_base = null;

    var wl_surface: ?*c.wl_surface = null;
    var xdg_surface: ?*c.xdg_surface = null;
    var xdg_toplevel: ?*c.xdg_toplevel = null;

    var egl_window: ?*c.wl_egl_window = null;

    var seat: ?*c.wl_seat = null;
    var pointer: ?*c.wl_pointer = null;
    var keyboard: ?*c.wl_keyboard = null;

    var xkb_ctx: ?*c.xkb_context = null;
    var xkb_keymap: ?*c.xkb_keymap = null;
    var xkb_state: ?*c.xkb_state = null;

    var egl_display: c.EGLDisplay = c.EGL_NO_DISPLAY;
    var egl_context: c.EGLContext = c.EGL_NO_CONTEXT;
    var egl_surface: c.EGLSurface = c.EGL_NO_SURFACE;
    var egl_config: c.EGLConfig = null;

    var win_width: c_int = 400;
    var win_height: c_int = 400;

    var frame_callback: ?*c.wl_callback = null;
    var program: c.GLuint = 0;
    var angle: c.float_t = 0.0;

    fn die(msg: []const u8) void {
        std.debug.print("---> Error: {s}\n", .{msg});
        std.process.exit(1);
    }

    const wm_base_listener: c.xdg_wm_base_listener = c.xdg_wm_base_listener{ .ping = xdg_wm_base_ping };
    fn xdg_wm_base_ping(_: ?*anyopaque, shell: ?*c.struct_xdg_wm_base, serial: u32) callconv(.c) void {
        c.xdg_wm_base_pong(shell, serial);
    }

    fn xdg_toplevel_configure(_: ?*anyopaque, _: ?*c.struct_xdg_toplevel, width: i32, height: i32, _: [*c]c.struct_wl_array) callconv(.c) void {
        if (width <= 0)
            return;

        if (height <= 0)
            return;

        win_width = width;
        win_height = height;

        if (egl_window != null)
            c.wl_egl_window_resize(egl_window, win_width, win_height, 0, 0);
    }

    fn xdg_toplevel_close(_: ?*anyopaque, _: ?*c.struct_xdg_toplevel) callconv(.c) void {
        std.debug.print("xdg_toplevel_close: exiting\n", .{});
        std.process.exit(0);
    }

    const xdg_toplevel_listener: c.xdg_toplevel_listener = c.xdg_toplevel_listener{
        .configure = xdg_toplevel_configure,
        .close = xdg_toplevel_close,
    };

    fn registry_global(_: ?*anyopaque, reg: ?*c.struct_wl_registry, id: u32, interface: [*c]const u8, _: u32) callconv(.c) void {
        const interfaceName: []const u8 = std.mem.span(interface);

        if (std.mem.eql(u8, interfaceName, "wl_compositor")) {
            compositor = @ptrCast(c.wl_registry_bind(reg, id, &c.wl_compositor_interface, 1));
        } else if (std.mem.eql(u8, interfaceName, "xdg_wm_base")) {
            wm_base = @ptrCast(c.wl_registry_bind(reg, id, &c.xdg_wm_base_interface, 1));
            _ = c.xdg_wm_base_add_listener(wm_base, &wm_base_listener, null);
        } else if (std.mem.eql(u8, interfaceName, "wl_seat")) {
            seat = @ptrCast(c.wl_registry_bind(registry, id, &c.wl_seat_interface, 1));
            _ = c.wl_seat_add_listener(seat, &seat_listener, null);
        }
    }

    fn registry_global_remove(_: ?*anyopaque, _: ?*c.struct_wl_registry, _: u32) callconv(.c) void {}

    const registry_listener: c.wl_registry_listener = c.wl_registry_listener{
        .global = registry_global,
        .global_remove = registry_global_remove,
    };

    fn egl_init() void {
        egl_display = c.eglGetDisplay(@as(c.EGLNativeDisplayType, display));
        if (egl_display == c.EGL_NO_DISPLAY)
            die("eglGetDisplay");

        if (c.eglInitialize(egl_display, null, null) == 0)
            die("eglInitialize");

        const attribs: [*c]const c.EGLint = &[_]c.EGLint{ c.EGL_SURFACE_TYPE, c.EGL_WINDOW_BIT, c.EGL_RED_SIZE, 8, c.EGL_GREEN_SIZE, 8, c.EGL_BLUE_SIZE, 8, c.EGL_ALPHA_SIZE, 8, c.EGL_RENDERABLE_TYPE, c.EGL_OPENGL_ES2_BIT, c.EGL_NONE };

        var num_configs: c.EGLint = undefined;
        const a = c.eglChooseConfig(egl_display, attribs, &egl_config, 1, &num_configs);

        if (a == 0)
            die("eglChooseConfig");

        if (num_configs < 1)
            die("eglChooseConfig");

        const ctx_attribs: [*c]const c.EGLint = &[_]c.EGLint{ c.EGL_CONTEXT_CLIENT_VERSION, 2, c.EGL_NONE };
        egl_context = c.eglCreateContext(egl_display, egl_config, c.EGL_NO_CONTEXT, ctx_attribs);
        if (egl_context == c.EGL_NO_CONTEXT)
            die("eglCreateContext");
    }

    fn compile_shader(gl_type: c.GLenum, src: [*c]const [*c]const u8) c.GLuint {
        const sh: c.GLuint = c.glCreateShader(gl_type);
        c.glShaderSource(sh, 1, src, null);
        c.glCompileShader(sh);
        var ok: c.GLint = 0;
        c.glGetShaderiv(sh, c.GL_COMPILE_STATUS, &ok);

        if (ok == 0) {
            var buf: [512]c.GLchar = undefined;
            var len: c.GLsizei = 0;

            c.glGetShaderInfoLog(sh, @sizeOf(@TypeOf(buf)), &len, &buf[0]);
            if (len < buf.len) buf[@intCast(len)] = 0;
            const log_slice: []const u8 = buf[0..@intCast(len)];

            std.debug.print("Shader compile error: {s}\n", .{log_slice});
            die("shader compile");
        }

        return sh;
    }

    fn make_program() c.GLuint {
        const vsrc_bytes =
            "attribute vec2 position;\n" ++
            "uniform float angle;\n" ++
            "void main() {\n" ++
            "  float c = cos(angle);\n" ++
            "  float s = sin(angle);\n" ++
            "  gl_Position = vec4(c*position.x - s*position.y, s*position.x + c*position.y, 0.0, 1.0);\n" ++
            "}\n";

        const vsrc_z = vsrc_bytes ++ "\x00"; // manual null terminator
        const vsrc: [*c]const u8 = vsrc_z.ptr;
        var vsrc_ptr: [*c]const u8 = vsrc;

        const fsrc_bytes =
            "precision mediump float;\n" ++
            "void main() {\n" ++
            "  gl_FragColor = vec4(0.2, 0.6, 0.9, 1.0);\n" ++
            "}\n";

        const fsrc_z = fsrc_bytes ++ "\x00";
        const fsrc: [*c]const u8 = fsrc_z.ptr;
        var fsrc_ptr: [*c]const u8 = fsrc;

        const vs = compile_shader(c.GL_VERTEX_SHADER, &vsrc_ptr);
        const fs = compile_shader(c.GL_FRAGMENT_SHADER, &fsrc_ptr);

        const prog: c.GLuint = c.glCreateProgram();
        c.glAttachShader(prog, vs);
        c.glAttachShader(prog, fs);
        c.glBindAttribLocation(prog, 0, "position");
        c.glLinkProgram(prog);

        var ok: c.GLint = 0;
        c.glGetProgramiv(prog, c.GL_LINK_STATUS, &ok);
        if (ok == 0) {
            var buf: [512]c.GLchar = undefined;
            var len: c.GLsizei = 0;

            c.glGetProgramInfoLog(prog, @sizeOf(@TypeOf(buf)), &len, &buf[0]);
            if (len < buf.len) buf[@intCast(len)] = 0;
            const log_slice: []const u8 = buf[0..@intCast(len)];

            std.debug.print("Shader compile error: {s}\n", .{log_slice});
        }

        c.glDeleteShader(vs);
        c.glDeleteShader(fs);

        return prog;
    }

    fn draw_square(prog: c.GLuint) void {
        c.glViewport(0, 0, win_width, win_height);
        c.glClearColor(0.1, 0.1, 0.1, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        c.glUseProgram(prog);
        c.glUniform1f(c.glGetUniformLocation(prog, "angle"), angle);

        c.glEnableVertexAttribArray(0);
        const verts: [12]c.GLfloat = [12]c.GLfloat{ -0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, -0.5, 0.5, 0.5, -0.5, 0.5 };
        c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, 0, &verts[0]);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 6);
        c.glDisableVertexAttribArray(0);
    }

    fn frame_done(_: ?*anyopaque, cb: ?*c.struct_wl_callback, _: u32) callconv(.c) void {
        if (cb != null)
            c.wl_callback_destroy(cb);

        angle += 0.02;

        draw_square(program);
        _ = c.eglSwapBuffers(egl_display, egl_surface);

        // Schedule next frame callback for main surface
        frame_callback = c.wl_surface_frame(wl_surface);
        const frame_listener: c.wl_callback_listener = c.wl_callback_listener{ .done = frame_done };
        _ = c.wl_callback_add_listener(frame_callback, &frame_listener, null);
        c.wl_surface_commit(wl_surface);
    }

    fn xdg_surface_configure(data: ?*anyopaque, surface: ?*c.struct_xdg_surface, serial: u32) callconv(.c) void {
        c.xdg_surface_ack_configure(surface, serial);

        if (frame_callback == null)
            frame_done(data, null, 0);
    }

    const xdg_surface_listener: c.xdg_surface_listener = c.xdg_surface_listener{ .configure = xdg_surface_configure };

    fn pointer_enter(_: ?*anyopaque, _: ?*c.struct_wl_pointer, _: u32, _: ?*c.struct_wl_surface, sx: c.wl_fixed_t, sy: c.wl_fixed_t) callconv(.c) void {
        std.debug.print("Pointer entered surface at {}, {}\n", .{ c.wl_fixed_to_double(sx), c.wl_fixed_to_double(sy) });
    }

    fn pointer_leave(_: ?*anyopaque, _: ?*c.struct_wl_pointer, _: u32, _: ?*c.struct_wl_surface) callconv(.c) void {
        std.debug.print("Pointer left surface\n", .{});
    }

    fn pointer_motion(_: ?*anyopaque, _: ?*c.struct_wl_pointer, _: u32, sx: c.wl_fixed_t, sy: c.wl_fixed_t) callconv(.c) void {
        std.debug.print("Pointer moved to {}, {}\n", .{ c.wl_fixed_to_double(sx), c.wl_fixed_to_double(sy) });
    }

    fn pointer_button(_: ?*anyopaque, _: ?*c.struct_wl_pointer, _: u32, _: u32, button: u32, state: u32) callconv(.c) void {
        std.debug.print("Pointer button {}, {s}\n", .{ button, if (state == c.WL_POINTER_BUTTON_STATE_PRESSED) "pressed" else "released" });
    }

    fn pointer_axis(_: ?*anyopaque, _: ?*c.struct_wl_pointer, _: u32, _: u32, value: c.wl_fixed_t) callconv(.c) void {
        std.debug.print("Pointer scrolled: {}\n", .{c.wl_fixed_to_double(value)});
    }

    fn keyboard_enter(_: ?*anyopaque, _: ?*c.struct_wl_keyboard, _: u32, _: ?*c.struct_wl_surface, _: ?*c.struct_wl_array) callconv(.c) void {
        std.debug.print("Keyboard focus on surface\n", .{});
    }

    fn keyboard_leave(_: ?*anyopaque, _: ?*c.struct_wl_keyboard, _: u32, _: ?*c.struct_wl_surface) callconv(.c) void {
        std.debug.print("Keyboard focus left surface\n", .{});
    }

    fn keyboard_key(_: ?*anyopaque, _: ?*c.struct_wl_keyboard, _: u32, _: u32, key: u32, state: u32) callconv(.c) void {
        const pressed = state == c.WL_KEYBOARD_KEY_STATE_PRESSED;

        _ = c.xkb_state_update_key(xkb_state, key + 8, if (pressed) c.XKB_KEY_DOWN else c.XKB_KEY_UP);

        var buf: [32]u8 = undefined;
        const n: i32 = c.xkb_state_key_get_utf8(xkb_state, key + 8, &buf[0], @sizeOf(@TypeOf(buf)));
        if (n > 0) {
            buf[@intCast(n)] = 0;
            std.debug.print("Key {s}: {s}\n", .{ if (pressed) "pressed" else "released", buf });
        }
    }

    fn keyboard_modifiers(_: ?*anyopaque, _: ?*c.struct_wl_keyboard, _: u32, _: u32, _: u32, _: u32, _: u32) callconv(.c) void {}

    fn keyboard_keymap(_: ?*anyopaque, _: ?*c.struct_wl_keyboard, format: u32, fd: i32, size: u32) callconv(.c) void {
        defer std.posix.close(fd);

        if (format != c.WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1)
            return;

        var map_str = std.posix.mmap(null, size, std.posix.PROT.READ, .{
            .TYPE = .SHARED,
        }, fd, 0) catch {
            die("mmap");
            return;
        };

        xkb_ctx = c.xkb_context_new(c.XKB_CONTEXT_NO_FLAGS);
        if (xkb_ctx == null)
            die("Failed to create xkb context");

        xkb_keymap = c.xkb_keymap_new_from_string(xkb_ctx, &map_str[0], c.XKB_KEYMAP_FORMAT_TEXT_V1, 0);
        if (xkb_keymap == null)
            die("Failed to create keymap");

        xkb_state = c.xkb_state_new(xkb_keymap);
        if (xkb_state == null)
            die("Failed to create state");
    }

    fn seat_capabilities(_: ?*anyopaque, _seat: ?*c.struct_wl_seat, caps: u32) callconv(.c) void {
        if (caps & c.WL_SEAT_CAPABILITY_POINTER != 0 and pointer == null) {
            pointer = c.wl_seat_get_pointer(_seat);
            const pointer_listener: c.struct_wl_pointer_listener = c.struct_wl_pointer_listener{
                .enter = pointer_enter,
                .leave = pointer_leave,
                .motion = pointer_motion,
                .button = pointer_button,
                .axis = pointer_axis,
            };
            _ = c.wl_pointer_add_listener(pointer, &pointer_listener, null);
        }

        if (caps & c.WL_SEAT_CAPABILITY_KEYBOARD != 0 and keyboard == null) {
            keyboard = c.wl_seat_get_keyboard(_seat);
            const keyboard_listener: c.struct_wl_keyboard_listener = c.struct_wl_keyboard_listener{
                .keymap = keyboard_keymap,
                .enter = keyboard_enter,
                .leave = keyboard_leave,
                .key = keyboard_key,
                .modifiers = keyboard_modifiers,
            };
            _ = c.wl_keyboard_add_listener(keyboard, &keyboard_listener, null);
        }
    }

    const seat_listener: c.struct_wl_seat_listener = c.struct_wl_seat_listener{ .capabilities = seat_capabilities, .name = null };

    pub fn init() void {
        display = c.wl_display_connect(null);
        if (display == null)
            die("wl_display_connect");

        registry = c.wl_display_get_registry(display);
        _ = c.wl_registry_add_listener(registry, &registry_listener, null);
        _ = c.wl_display_roundtrip(display);

        if (compositor == null)
            die("Compositor missing wl_compositor\n");

        if (wm_base == null)
            die("Compositor missing xdg_wm_base\n");

        // main surface
        wl_surface = c.wl_compositor_create_surface(compositor);
        xdg_surface = c.xdg_wm_base_get_xdg_surface(wm_base, wl_surface);
        _ = c.xdg_surface_add_listener(xdg_surface, &xdg_surface_listener, null);

        xdg_toplevel = c.xdg_surface_get_toplevel(xdg_surface);
        _ = c.xdg_toplevel_add_listener(xdg_toplevel, &xdg_toplevel_listener, null);
        c.xdg_toplevel_set_title(xdg_toplevel, "Rotating Square");

        // egl setup
        egl_init();
        egl_window = c.wl_egl_window_create(wl_surface, win_width, win_height);
        egl_surface = c.eglCreateWindowSurface(egl_display, egl_config, @as(c.EGLNativeWindowType, egl_window), null);
        _ = c.eglMakeCurrent(egl_display, egl_surface, egl_surface, egl_context);

        program = make_program();

        // commit main surface so configure fires
        c.wl_surface_commit(wl_surface);

        while (true) {
            _ = c.wl_display_dispatch_pending(display);
            _ = c.wl_display_flush(display);

            if (c.wl_display_prepare_read(display) == 0) {
                _ = c.wl_display_flush(display);
                _ = c.wl_display_read_events(display);
            } else {
                _ = c.wl_display_dispatch_pending(display);
            }
        }

        return 0;
    }
};
