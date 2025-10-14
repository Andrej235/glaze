const std = @import("std");
const c = @cImport({
    @cInclude("windows.h");
    @cInclude("../src/renderer/gl/glad/include/glad/gl.h");
    @cInclude("../src/renderer/gl/glad/include/glad/wgl.h");
});

const caster = @import("../utils/caster.zig");
const key_code = @import("../input-system/keycode/keycode.zig");
const event_manager = @import("../event-system/event_manager.zig");
const window_state = @import("../event-system/models/window_state.zig");
const arena_allocator_utils = @import("../utils/arena_allocator_util.zig");

const c_allocator_utils = @import("../utils/c_allocator_util.zig");
const cAlloc = c_allocator_utils.cAlloc;

const App = @import("../app.zig").App;
const GL = @import("../renderer/gl/gl.zig").Gl;
const Window = @import("../renderer/window.zig").Window;
const GLContext = @import("../renderer/gl/gl-context.zig").GlContext;
const HighResTimer = @import("../utils/high_res_timer.zig").HighResTimer;
const WindowSize = @import("../event-system/models/window_size.zig").WindowSize;
const MousePosition = @import("../event-system/models/mouse_position.zig").MousePosition;
const EventDispatcher = @import("../event-system/event_dispatcher.zig").EventDispatcher;

const HWND = c.HWND;
const WNDCLASS = c.WNDCLASS;

const Result = struct {
    gl: ?*GL,
    on_request_frame: ?*EventDispatcher(void, *anyopaque),
};

pub const Windows = struct {
    app: *App,

    hwnd: HWND,
    hdc: c.HDC,

    on_request_frame: *EventDispatcher(void, *anyopaque),

    pub fn init(title: [*:0]const u8, width: i16, height: i16, on_request_frame: *EventDispatcher(void, *anyopaque)) !Windows {
        const class_name: [*c]const u8 = "GlazeWindowClass";

        var wc: WNDCLASS = .{};
        wc.lpfnWndProc = windowsMessageHandler;
        wc.lpszClassName = class_name;
        wc.hInstance = c.GetModuleHandleA(null);
        wc.hbrBackground = c.CreateSolidBrush(0x00000000);

        _ = c.RegisterClassA(&wc);

        const screen_position: ScreenPosition = getScreenCenterPosition(width, height);
        const hwnd: HWND = c.CreateWindowExA(
            0,
            class_name,
            title,
            c.WS_OVERLAPPEDWINDOW,
            screen_position.x,
            screen_position.y,
            width,
            height,
            null,
            null,
            wc.hInstance,
            null,
        );

        // Setup OpenGL context
        const hdc: c.HDC = createGLContext(hwnd);

        // Create instance
        return Windows{
            .app = App.get(),
            .hwnd = hwnd,
            .hdc = hdc,
            .on_request_frame = on_request_frame,
        };
    }

    pub fn initWindow(width: i32, height: i32, window_title: [*:0]const u8) anyerror!*Window {
        // Create result instance that will be populated with data after windows thread is finished loading
        const result: *Result = try cAlloc(Result);
        result.* = Result{
            .gl = null,
            .on_request_frame = null,
        };

        // Spawn new main thread
        _ = try std.Thread.spawn(.{}, loadWindowsWithGLContext, .{ width, height, window_title, result });

        while (result.*.gl == null and result.*.on_request_frame == null) {
            std.Thread.sleep(2 * std.time.ns_per_ms);
        }

        // Create new instance of window
        const window: *Window = try cAlloc(Window);
        window.* = Window{
            .gl = result.gl.?,
            .width = width,
            .height = height,
            .on_request_frame = result.on_request_frame.?,
        };

        return window;
    }

    pub fn runMainLoop(self: *Windows) !void {
        var msg: c.MSG = undefined;
        var timer = HighResTimer.init();

        var frame_count: u32 = 0;
        var elapsed_time: f64 = 0.0;

        while (true) {
            while (c.PeekMessageA(&msg, null, 0, 0, c.PM_REMOVE) != 0) {
                if (msg.message == c.WM_QUIT) return;
                _ = c.TranslateMessage(&msg);
                _ = c.DispatchMessageA(&msg);
            }

            // -------- Pre Render --------
            const delta_ms = timer.deltaMilliseconds();
            elapsed_time += delta_ms;

            self.app.event_system.render_events.on_update.dispatch(delta_ms) catch |e| {
                std.log.err("Error rendering events: {}", .{e});
            };

            // -------- Rendering --------
            self.on_request_frame.dispatch({}) catch |e| {
                std.log.err("Error requesting frame: {}", .{e});
            };

            c.glLoadIdentity();

            // -------- Post Render --------
            self.app.event_system.dispatchEventOnEventThread(.{ .PostRender = delta_ms });

            // -------- End of Frame --------
            frame_count += 1;

            if (elapsed_time >= 1000.0) {
                // Sets FPS in window title
                var buffer: [64]u8 = undefined;
                const fps_text = try std.fmt.bufPrintZ(&buffer, "Glaze Engine - FPS: {}", .{frame_count});
                _ = c.SetWindowTextA(self.hwnd, fps_text);

                frame_count = 0;
                elapsed_time = 0.0;
            }
        }
    }

    fn windowsMessageHandler(hwnd: c.HWND, uMsg: c.UINT, wParam: c.WPARAM, lParam: c.LPARAM) callconv(.c) c.LRESULT {
        const app: *App = App.get();

        switch (uMsg) {
            c.WM_DESTROY => {
                // Fire events
                app.event_system.dispatchEventOnEventThread(.{ .WindowDestroy = {} });

                c.PostQuitMessage(0);

                std.process.exit(0);
            },

            c.WM_CLOSE => {
                // Fire events
                app.event_system.dispatchEventOnEventThread(.{ .WindowClose = {} });

                c.PostQuitMessage(0);

                std.process.exit(0);
            },

            c.WM_KEYDOWN => {
                // Fire events
                const key: key_code.KeyCode = key_code.keycodeFromInt(@intCast(wParam));
                app.input_system.registerKey(key);
                app.event_system.dispatchEventOnEventThread(.{ .KeyDown = key });

                return 0;
            },

            c.WM_KEYUP => {
                // Fire events
                const key: key_code.KeyCode = key_code.keycodeFromInt(@intCast(wParam));
                app.input_system.unregisterKey(key);
                app.event_system.dispatchEventOnEventThread(.{ .KeyUp = key });

                return 0;
            },

            c.WM_SIZE => {
                const size: WindowSize = WindowSize.init(
                    @intCast(lParam & 0xFFFF),
                    @intCast((lParam >> 16) & 0xFFFF),
                    window_state.windowStateFromCInt(@intCast(wParam)),
                );

                app.renderer.window.width = @intCast(size.width);
                app.renderer.window.height = @intCast(size.height);

                app.event_system.dispatchEventOnEventThread(.{ .WindowResize = size });

                return 0;
            },

            c.WM_MOUSEMOVE => {
                const position: MousePosition = MousePosition.init(@intCast(lParam & 0xFFFF), @intCast((lParam >> 16) & 0xFFFF));
                app.event_system.dispatchEventOnEventThread(.{ .MouseMove = position });

                return 0;
            },

            c.WM_SETFOCUS => {
                app.event_system.dispatchEventOnEventThread(.{ .WindowFocusGain = {} });

                return 0;
            },

            c.WM_KILLFOCUS => {
                app.event_system.dispatchEventOnEventThread(.{ .WindowFocusLose = {} });

                return 0;
            },

            else => return c.DefWindowProcA(hwnd, uMsg, wParam, lParam),
        }
    }

    fn getScreenCenterPosition(window_width: i32, window_height: i32) ScreenPosition {
        const screen_width: c_int = c.GetSystemMetrics(c.SM_CXSCREEN);
        const screen_height: c_int = c.GetSystemMetrics(c.SM_CYSCREEN);

        return ScreenPosition{
            .x = @divTrunc(screen_width - window_width, 2),
            .y = @divTrunc(screen_height - window_height, 2),
        };
    }

    //#region GLContext
    fn createGLContext(hwnd: HWND) c.HDC {
        const hdc = c.GetDC(hwnd);

        var pfd: c.PIXELFORMATDESCRIPTOR = std.mem.zeroes(c.PIXELFORMATDESCRIPTOR);
        pfd.nSize = @sizeOf(c.PIXELFORMATDESCRIPTOR);
        pfd.nVersion = 1;
        pfd.dwFlags = c.PFD_DRAW_TO_WINDOW | c.PFD_SUPPORT_OPENGL | c.PFD_DOUBLEBUFFER;
        pfd.iPixelType = c.PFD_TYPE_RGBA;
        pfd.cColorBits = 32;
        pfd.cDepthBits = 24;
        pfd.iLayerType = c.PFD_MAIN_PLANE;

        const pf = c.ChoosePixelFormat(hdc, &pfd);
        _ = c.SetPixelFormat(hdc, pf, &pfd);

        const hglrc = c.wglCreateContext(hdc);
        _ = c.wglMakeCurrent(hdc, hglrc);

        _ = c.gladLoadWGL(hdc, @ptrCast(&c.wglGetProcAddress));

        disableVSync();

        return hdc;
    }

    fn disableVSync() void {
        const wglSwapIntervalEXT: ?*const fn (interval: c_int) callconv(.c) c_int = @ptrCast(c.wglGetProcAddress("wglSwapIntervalEXT"));

        if (wglSwapIntervalEXT) |setInterval| {
            _ = setInterval(0); // Disable vsync
            std.debug.print("VSync disabled\n", .{});
        } else {
            std.debug.print("VSync control not supported\n", .{});
        }
    }

    fn loadWindowsWithGLContext(width: i32, height: i32, window_title: [*:0]const u8, result: *Result) !void {
        // Create new instance of event dispatcher for on_request_frame
        const on_request_frame = try EventDispatcher(void, *anyopaque).create();

        // Create new instance of windows
        const windows = try std.heap.c_allocator.create(Windows);
        windows.* = try Windows.init(window_title, @intCast(width), @intCast(height), on_request_frame);

        // Create and allocate memory for GL context and GL
        const glContext: *GLContext = try cAlloc(GLContext);
        glContext.* = GLContext{
            .swap_buffers = glContextswapBufferWrap,
            .load_glad = glContextloadGladWrap,
            .destroy = glContextDestroyWrap,
            .data = windows,
        };

        const gl: *GL = try cAlloc(GL);
        gl.* = try GL.init(glContext);

        result.*.gl = gl;
        result.*.on_request_frame = on_request_frame;

        _ = c.ShowWindow(windows.hwnd, c.SW_SHOW);

        try windows.runMainLoop();
    }
    //#endregion

    //#region GLContext Wrappers
    fn glContextswapBufferWrap(self: *GLContext) anyerror!void {
        const windows: *Windows = try caster.castFromNullableAnyopaque(Windows, self.data);

        _ = c.SwapBuffers(windows.hdc);
    }

    fn glContextloadGladWrap(_: *GLContext) anyerror!void {
        if (c.gladLoadGL(loadGLProc) == 0) {
            std.log.err("Failed to load GL functions", .{});
        }
    }

    fn glContextDestroyWrap(_: *GLContext) void {}

    fn loadGLProc(name: [*c]const u8) callconv(.c) ?*const fn () callconv(.c) void {
        const addr = c.wglGetProcAddress(name);
        if (addr != null) return @ptrCast(addr);

        const lib = c.GetModuleHandleA("opengl32.dll");
        if (lib != null) {
            const addr2 = c.GetProcAddress(lib, name);
            if (addr2 != null)
                return @ptrCast(addr2);
        }

        return null;
    }
    //#endregion
};

const ScreenPosition = struct { x: i32, y: i32 };
