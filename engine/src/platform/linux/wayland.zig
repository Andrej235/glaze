const std = @import("std");

const Event = @import("../../event-system/event_dispatcher.zig").EventDispatcher;
const Gl = @import("../../renderer/gl.zig").GL;
const GlContext = @import("../../renderer/gl-context.zig").GlContext;
const Window = @import("../../renderer/window.zig").Window;
const Caster = @import("../../utils/caster.zig");

const c = @cImport({
    @cInclude("wayland-client.h");
    @cInclude("wayland-egl.h");
    @cInclude("EGL/egl.h");
    @cInclude("GLES2/gl2.h");
    @cInclude("xkbcommon/xkbcommon.h");
    @cInclude("platform/linux//xdg-shell-client-protocol.h");
});

pub const Wayland = struct {
    gl_initialization_complete_event_dispatcher: *Event(*Wayland),
    frame_event_dispatcher: *Event(void),

    display: ?*c.wl_display = null,
    registry: ?*c.wl_registry = null,
    compositor: ?*c.wl_compositor = null,
    wm_base: ?*c.xdg_wm_base = null,

    wl_surface: ?*c.wl_surface = null,
    xdg_surface: ?*c.xdg_surface = null,
    xdg_toplevel: ?*c.xdg_toplevel = null,

    egl_window: ?*c.wl_egl_window = null,

    seat: ?*c.wl_seat = null,
    pointer: ?*c.wl_pointer = null,
    keyboard: ?*c.wl_keyboard = null,

    xkb_ctx: ?*c.xkb_context = null,
    xkb_keymap: ?*c.xkb_keymap = null,
    xkb_state: ?*c.xkb_state = null,

    egl_display: c.EGLDisplay = c.EGL_NO_DISPLAY,
    egl_context: c.EGLContext = c.EGL_NO_CONTEXT,
    egl_surface: c.EGLSurface = c.EGL_NO_SURFACE,
    egl_config: c.EGLConfig = null,

    win_width: c_int = 400,
    win_height: c_int = 400,

    frame_callback: ?*c.wl_callback = null,
    program: c.GLuint = 0,

    fn die(msg: []const u8) void {
        std.debug.print("---> Error: {s}\n", .{msg});
        std.process.exit(1);
    }

    fn init_egl(self: *Wayland) void {
        self.egl_display = c.eglGetDisplay(@as(c.EGLNativeDisplayType, self.display));
        if (self.egl_display == c.EGL_NO_DISPLAY)
            die("eglGetDisplay");

        if (c.eglInitialize(self.egl_display, null, null) == 0)
            die("eglInitialize");

        const attribs: [*c]const c.EGLint = &[_]c.EGLint{ c.EGL_SURFACE_TYPE, c.EGL_WINDOW_BIT, c.EGL_RED_SIZE, 8, c.EGL_GREEN_SIZE, 8, c.EGL_BLUE_SIZE, 8, c.EGL_ALPHA_SIZE, 8, c.EGL_RENDERABLE_TYPE, c.EGL_OPENGL_ES2_BIT, c.EGL_NONE };

        var num_configs: c.EGLint = undefined;
        const config = c.eglChooseConfig(self.egl_display, attribs, &self.egl_config, 1, &num_configs);

        if (config == 0)
            die("eglChooseConfig");

        if (num_configs < 1)
            die("eglChooseConfig");

        const ctx_attribs: [*c]const c.EGLint = &[_]c.EGLint{ c.EGL_CONTEXT_CLIENT_VERSION, 2, c.EGL_NONE };
        self.egl_context = c.eglCreateContext(self.egl_display, self.egl_config, c.EGL_NO_CONTEXT, ctx_attribs);
        if (self.egl_context == c.EGL_NO_CONTEXT)
            die("eglCreateContext");

        self.egl_window = c.wl_egl_window_create(self.wl_surface, self.win_width, self.win_height);
        self.egl_surface = c.eglCreateWindowSurface(self.egl_display, self.egl_config, @as(c.EGLNativeWindowType, self.egl_window), null);

        _ = c.eglMakeCurrent(self.egl_display, self.egl_surface, self.egl_surface, self.egl_context);
    }

    fn frame_done(data: ?*anyopaque, cb: ?*c.struct_wl_callback, _: u32) callconv(.c) void {
        const self: *Wayland = @ptrCast(@alignCast(data));

        if (cb != null)
            c.wl_callback_destroy(cb);

        // if there are no frame handlers just swap buffers to allow for the next frame to even fire
        if (self.frame_event_dispatcher.handlers.items.len == 0) {
            std.debug.print("No frame handlers\n", .{});
            _ = c.eglSwapBuffers(self.egl_display, self.egl_surface);
        }

        self.frame_event_dispatcher.dispatch({}) catch {
            std.log.err("Failed to dispatch frame event", .{});
        };

        // schedule next frame callback for main surface
        self.frame_callback = c.wl_surface_frame(self.wl_surface);
        const frame_listener: c.wl_callback_listener = c.wl_callback_listener{ .done = frame_done };
        _ = c.wl_callback_add_listener(self.frame_callback, &frame_listener, data);

        c.wl_surface_commit(self.wl_surface);
    }

    fn ensure_render_loop_started(self: *Wayland) void {
        if (self.frame_callback == null) {
            frame_done(self, null, 0);
        }
    }

    fn init_listeners(self: *Wayland) void {
        const callbacks = struct {
            fn xdg_wm_base_ping(_: ?*anyopaque, shell: ?*c.struct_xdg_wm_base, serial: u32) callconv(.c) void {
                c.xdg_wm_base_pong(shell, serial);
            }

            fn xdg_toplevel_configure(data: ?*anyopaque, _: ?*c.struct_xdg_toplevel, width: i32, height: i32, _: [*c]c.struct_wl_array) callconv(.c) void {
                const inner_self: *Wayland = @ptrCast(@alignCast(data));

                if (width <= 0)
                    return;

                if (height <= 0)
                    return;

                inner_self.win_width = width;
                inner_self.win_height = height;

                if (inner_self.egl_window != null)
                    c.wl_egl_window_resize(inner_self.egl_window, inner_self.win_width, inner_self.win_height, 0, 0);
            }

            fn xdg_toplevel_close(_: ?*anyopaque, _: ?*c.struct_xdg_toplevel) callconv(.c) void {
                std.debug.print("xdg_toplevel_close: exiting\n", .{});
                std.process.exit(0);
            }

            fn seat_capabilities(data: ?*anyopaque, _seat: ?*c.struct_wl_seat, caps: u32) callconv(.c) void {
                const inner_self: *Wayland = @ptrCast(@alignCast(data));

                if (caps & c.WL_SEAT_CAPABILITY_POINTER != 0 and inner_self.pointer == null) {
                    const fns = struct {
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
                    };

                    inner_self.pointer = c.wl_seat_get_pointer(_seat);
                    const pointer_listener: c.struct_wl_pointer_listener = c.struct_wl_pointer_listener{
                        .enter = fns.pointer_enter,
                        .leave = fns.pointer_leave,
                        .motion = fns.pointer_motion,
                        .button = fns.pointer_button,
                        .axis = fns.pointer_axis,
                    };
                    _ = c.wl_pointer_add_listener(inner_self.pointer, &pointer_listener, data);
                }

                if (caps & c.WL_SEAT_CAPABILITY_KEYBOARD != 0 and inner_self.keyboard == null) {
                    const fns = struct {
                        fn keyboard_enter(_: ?*anyopaque, _: ?*c.struct_wl_keyboard, _: u32, _: ?*c.struct_wl_surface, _: ?*c.struct_wl_array) callconv(.c) void {
                            std.debug.print("Keyboard focus on surface\n", .{});
                        }

                        fn keyboard_leave(_: ?*anyopaque, _: ?*c.struct_wl_keyboard, _: u32, _: ?*c.struct_wl_surface) callconv(.c) void {
                            std.debug.print("Keyboard focus left surface\n", .{});
                        }

                        fn keyboard_key(inner_data: ?*anyopaque, _: ?*c.struct_wl_keyboard, _: u32, _: u32, key: u32, state: u32) callconv(.c) void {
                            const inner_inner_self: *Wayland = @ptrCast(@alignCast(inner_data));
                            const pressed = state == c.WL_KEYBOARD_KEY_STATE_PRESSED;

                            _ = c.xkb_state_update_key(inner_inner_self.xkb_state, key + 8, if (pressed) c.XKB_KEY_DOWN else c.XKB_KEY_UP);

                            var buf: [32]u8 = undefined;
                            const n: i32 = c.xkb_state_key_get_utf8(inner_inner_self.xkb_state, key + 8, &buf[0], @sizeOf(@TypeOf(buf)));
                            if (n > 0) {
                                buf[@intCast(n)] = 0;
                                std.debug.print("Key {s}: {s}\n", .{ if (pressed) "pressed" else "released", buf });
                            }
                        }

                        fn keyboard_modifiers(_: ?*anyopaque, _: ?*c.struct_wl_keyboard, _: u32, _: u32, _: u32, _: u32, _: u32) callconv(.c) void {}

                        fn keyboard_keymap(inner_data: ?*anyopaque, _: ?*c.struct_wl_keyboard, format: u32, fd: i32, size: u32) callconv(.c) void {
                            const inner_inner_self: *Wayland = @ptrCast(@alignCast(inner_data));
                            defer std.posix.close(fd);

                            if (format != c.WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1)
                                return;

                            var map_str = std.posix.mmap(null, size, std.posix.PROT.READ, .{
                                .TYPE = .SHARED,
                            }, fd, 0) catch {
                                die("mmap");
                                return;
                            };

                            inner_inner_self.xkb_ctx = c.xkb_context_new(c.XKB_CONTEXT_NO_FLAGS);
                            if (inner_inner_self.xkb_ctx == null)
                                die("Failed to create xkb context");

                            inner_inner_self.xkb_keymap = c.xkb_keymap_new_from_string(inner_inner_self.xkb_ctx, &map_str[0], c.XKB_KEYMAP_FORMAT_TEXT_V1, 0);
                            if (inner_inner_self.xkb_keymap == null)
                                die("Failed to create keymap");

                            inner_inner_self.xkb_state = c.xkb_state_new(inner_inner_self.xkb_keymap);
                            if (inner_inner_self.xkb_state == null)
                                die("Failed to create state");
                        }
                    };

                    inner_self.keyboard = c.wl_seat_get_keyboard(_seat);
                    const keyboard_listener: c.struct_wl_keyboard_listener = c.struct_wl_keyboard_listener{
                        .keymap = fns.keyboard_keymap,
                        .enter = fns.keyboard_enter,
                        .leave = fns.keyboard_leave,
                        .key = fns.keyboard_key,
                        .modifiers = fns.keyboard_modifiers,
                    };
                    _ = c.wl_keyboard_add_listener(inner_self.keyboard, &keyboard_listener, inner_self);
                }
            }

            fn registry_global(data: ?*anyopaque, reg: ?*c.struct_wl_registry, id: u32, interface: [*c]const u8, _: u32) callconv(.c) void {
                const inner_self: *Wayland = @ptrCast(@alignCast(data));

                const interfaceName: []const u8 = std.mem.span(interface);
                if (std.mem.eql(u8, interfaceName, "wl_compositor")) {
                    inner_self.compositor = @ptrCast(c.wl_registry_bind(reg, id, &c.wl_compositor_interface, 1));
                } else if (std.mem.eql(u8, interfaceName, "xdg_wm_base")) {
                    inner_self.wm_base = @ptrCast(c.wl_registry_bind(reg, id, &c.xdg_wm_base_interface, 1));
                    const wm_base_listener: c.xdg_wm_base_listener = c.xdg_wm_base_listener{ .ping = xdg_wm_base_ping };
                    _ = c.xdg_wm_base_add_listener(inner_self.wm_base, &wm_base_listener, data);
                } else if (std.mem.eql(u8, interfaceName, "wl_seat")) {
                    // inner_self.seat = @ptrCast(c.wl_registry_bind(inner_self.registry, id, &c.wl_seat_interface, 1));
                    // const seat_listener: c.struct_wl_seat_listener = c.struct_wl_seat_listener{ .capabilities = seat_capabilities, .name = null };
                    // _ = c.wl_seat_add_listener(inner_self.seat, &seat_listener, data);
                }
            }

            fn registry_global_remove(_: ?*anyopaque, _: ?*c.struct_wl_registry, _: u32) callconv(.c) void {}

            fn xdg_surface_configure(data: ?*anyopaque, surface: ?*c.struct_xdg_surface, serial: u32) callconv(.c) void {
                const inner_self: *Wayland = @ptrCast(@alignCast(data));
                c.xdg_surface_ack_configure(surface, serial);

                inner_self.gl_initialization_complete_event_dispatcher.dispatch(inner_self) catch unreachable;
            }
        };

        const xdg_toplevel_listener: c.xdg_toplevel_listener = c.xdg_toplevel_listener{
            .configure = callbacks.xdg_toplevel_configure,
            .close = callbacks.xdg_toplevel_close,
        };

        const registry_listener: c.wl_registry_listener = c.wl_registry_listener{
            .global = callbacks.registry_global,
            .global_remove = callbacks.registry_global_remove,
        };

        const xdg_surface_listener: c.xdg_surface_listener = c.xdg_surface_listener{ .configure = callbacks.xdg_surface_configure };

        self.registry = c.wl_display_get_registry(self.display);
        _ = c.wl_registry_add_listener(self.registry, &registry_listener, self);
        _ = c.wl_display_roundtrip(self.display);

        if (self.compositor == null)
            die("Compositor missing wl_compositor\n");

        if (self.wm_base == null)
            die("Compositor missing xdg_wm_base\n");

        // main surface
        self.wl_surface = c.wl_compositor_create_surface(self.compositor);
        self.xdg_surface = c.xdg_wm_base_get_xdg_surface(self.wm_base, self.wl_surface);
        _ = c.xdg_surface_add_listener(self.xdg_surface, &xdg_surface_listener, self);

        self.xdg_toplevel = c.xdg_surface_get_toplevel(self.xdg_surface);
        _ = c.xdg_toplevel_add_listener(self.xdg_toplevel, &xdg_toplevel_listener, self);
        c.xdg_toplevel_set_title(self.xdg_toplevel, "Rotating Square");
    }

    fn run(wl: *Wayland) !void {
        wl.display = c.wl_display_connect(null);
        if (wl.display == null)
            die("wl_display_connect");

        wl.init_listeners();
        wl.init_egl();

        // configure can only fire after the first commit
        c.wl_surface_commit(wl.wl_surface);

        while (true) {
            _ = c.wl_display_dispatch_pending(wl.display);
            _ = c.wl_display_flush(wl.display);

            if (c.wl_display_prepare_read(wl.display) == 0) {
                _ = c.wl_display_flush(wl.display);
                _ = c.wl_display_read_events(wl.display);
            } else {
                _ = c.wl_display_dispatch_pending(wl.display);
            }
        }
    }

    pub fn init_window() anyerror!*Window {
        var allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

        const frame_event_dispatcher = try allocator.allocator().create(Event(void));
        frame_event_dispatcher.* = try Event(void).init(&allocator);
        const gl_initialization_complete_event_dispatcher = try allocator.allocator().create(Event(*Wayland));
        gl_initialization_complete_event_dispatcher.* = try Event(*Wayland).init(&allocator);

        const wl = try allocator.allocator().create(Wayland);
        wl.* = Wayland{
            .frame_event_dispatcher = frame_event_dispatcher,
            .gl_initialization_complete_event_dispatcher = gl_initialization_complete_event_dispatcher,
        };

        const Result = struct {
            gl: ?*Gl,
            allocator: *std.heap.ArenaAllocator,
        };

        const fns = struct {
            fn on_gl_initialization_complete(wayland: *Wayland, data: ?*anyopaque) anyerror!void {
                const fns = struct {
                    self: *Wayland,
                    fn make_current(ctx: *GlContext) anyerror!void {
                        std.debug.print("Making context current\n", .{});
                        const self = try Caster.castFromNullableAnyopaque(Wayland, ctx.data);
                        const ok = c.eglMakeCurrent(self.egl_display, self.egl_surface, self.egl_surface, self.egl_context);

                        if (ok == 0) {
                            const err = c.eglGetError();
                            std.debug.print("eglMakeCurrent FAILED: 0x{x}\n", .{err});
                        }
                    }
                    fn swap_buffers(ctx: *GlContext) anyerror!void {
                        const self = try Caster.castFromNullableAnyopaque(Wayland, ctx.data);
                        const ok = c.eglSwapBuffers(self.egl_display, self.egl_surface);

                        if (ok == 0) {
                            const e = c.eglGetError();
                            std.debug.print("eglSwapBuffers FAILED: 0x{x}\n", .{e});
                        }
                    }
                    fn get_proc_address(_: *GlContext, name: [*]const u8) ?*anyopaque {
                        const proc = c.eglGetProcAddress(name);
                        return if (proc) |p| @ptrCast(@constCast(p)) else null;
                    }
                    fn destroy(_: *GlContext) void {}
                };

                try wayland.gl_initialization_complete_event_dispatcher.removeHandler(on_gl_initialization_complete, data);
                std.debug.print("GL initialized (thread {})\n", .{std.Thread.getCurrentId()});

                const res = try Caster.castFromNullableAnyopaque(Result, data);
                const page_allocator = std.heap.page_allocator;

                const context = try page_allocator.create(GlContext);
                context.* = GlContext{
                    .destroy = fns.destroy,
                    .make_current = fns.make_current,
                    .swap_buffers = fns.swap_buffers,
                    .get_proc_address = fns.get_proc_address,
                    .data = wayland,
                };

                const gl = try page_allocator.create(Gl);
                gl.* = try Gl.init(context);

                res.gl = gl;

                ensure_render_loop_started(wayland);
            }
        };

        var res = Result{
            .gl = null,
            .allocator = &allocator,
        };

        try gl_initialization_complete_event_dispatcher.addHandler(fns.on_gl_initialization_complete, &res);

        _ = try std.Thread.spawn(.{}, run, .{wl});

        while (res.gl == null) {
            std.Thread.sleep(10_000_000);
        }

        std.debug.print("broke out (thread {})\n\n", .{std.Thread.getCurrentId()});

        const window = try allocator.allocator().create(Window);
        window.* = Window{
            .gl = res.gl.?,
            .on_request_frame = frame_event_dispatcher,
            .height = wl.win_height,
            .width = wl.win_width,
        };
        return window;
    }
};
