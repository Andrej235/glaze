const std = @import("std");
const c = @cImport({
    @cInclude("windows.h");
    @cInclude("GL/gl.h");
    @cInclude("GL/glu.h");
});

const key_code = @import("../event-system/models/key_code.zig");
const event_manager = @import("../event-system/event_manager.zig");
const window_state = @import("../event-system/models/window_state.zig");

const App = @import("../app.zig").App;
const Window = @import("../ui/window.zig").Window;
const HighResTimer = @import("../utils/high_res_timer.zig").HighResTimer;
const WindowSize = @import("../event-system/models/window_size.zig").WindowSize;
const MousePosition = @import("../event-system/models/mouse_position.zig").MousePosition;

const HWND = c.HWND;
const WNDCLASS = c.WNDCLASS;

pub const PlatformWindow = struct {
    arena_allocator: *std.heap.ArenaAllocator,

    app: *App,
    window: *Window,
    
    hwnd: HWND,
    hdc: c.HDC,

    pub fn init(arena_allocator: *std.heap.ArenaAllocator, window: *Window, title: []const u8, width: i16, height: i16) !PlatformWindow {
        const class_name: [*c]const u8 = "GlazeWindowClass";

        var wc: WNDCLASS = .{};
        wc.lpfnWndProc = WindowProc;
        wc.lpszClassName = class_name;
        wc.hInstance = c.GetModuleHandleA(null);
        wc.hbrBackground = c.CreateSolidBrush(0x00000000);

        _ = c.RegisterClassA(&wc);

        const screen_position: ScreenPosition = getMiddleXYPostionForWindow(width, height);
        const hwnd: HWND = c.CreateWindowExA(0, class_name, &title[0], c.WS_OVERLAPPEDWINDOW, screen_position.x, screen_position.y, width, height, null, null, wc.hInstance, null);

        // Store window instance in HWND
        _ = c.SetWindowLongPtrA(hwnd, c.GWLP_USERDATA, @intCast(@intFromPtr(window)));

        // Setup OpenGL context
        const hdc: c.HDC = setupWindowsOpenGLContext(hwnd, width, height);

        // Create instance
        return PlatformWindow{ .arena_allocator = arena_allocator, .app = window.app, .window = window, .hwnd = hwnd, .hdc = hdc };
    }

    pub fn show(self: *PlatformWindow) !void {
        if (self.hwnd) |ptr| {
            _ = c.ShowWindow(ptr, c.SW_SHOW);
        } else {
            return error.NullPointer;
        }
    }

    pub fn run(self: *PlatformWindow) !void {
        var msg: c.MSG = undefined;
        var timer: HighResTimer = HighResTimer.init();

        while (true) {

            // Processes all available messages
            // If there are not messages continue loop
            while (c.PeekMessageA(&msg, null, 0, 0, c.PM_REMOVE) != 0) {
                if (msg.message == c.WM_QUIT) return;

                _ = c.TranslateMessage(&msg);
                _ = c.DispatchMessageA(&msg);
            }

            // -------- Pre Render --------
            const delta_ms = timer.deltaMilliseconds();

            self.app.event_system.render_events.on_update.dispatch(delta_ms) catch |e| {
                std.debug.print("Error dispatching update: {}\n", .{e});
            };

            // -------- Rendering --------
            c.glClearColor(0.1, 0.1, 0.1, 1.0);
            c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);

            self.app.event_system.render_events.on_render.dispatch({}) catch |e| {
                std.debug.print("Error dispatching render update: {}\n", .{e});
            };

            c.glLoadIdentity();

            _ = c.SwapBuffers(self.hdc);

            // -------- Post Render --------
            self.app.event_system.render_events.on_post_render.dispatch(delta_ms) catch |e| {
                std.debug.print("Error dispatching update: {}\n", .{e});
            };
        }
    }

    /// Window message handler
    fn WindowProc(hwnd: c.HWND, uMsg: c.UINT, wParam: c.WPARAM, lParam: c.LPARAM) callconv(.c) c.LRESULT {
        // Get window instance ptr from HWND
        const window_long_ptr: usize = @intCast(c.GetWindowLongPtrA(hwnd, c.GWLP_USERDATA));
        const window_instance: ?*Window = @ptrFromInt(window_long_ptr);

        switch (uMsg) {
            c.WM_DESTROY => {
                // Fire events
                if (window_instance) |win| {
                    _ = win.app.event_system.window_events.on_window_destroy.dispatch({}) catch |e| {
                        std.debug.print("Error dispatching destroy: {}\n", .{e});
                    };
                }

                c.PostQuitMessage(0);
                return 0;
            },

            c.WM_CLOSE => {
                // Fire events
                if (window_instance) |win| {
                    _ = win.app.event_system.window_events.on_window_close.dispatch({}) catch |e| {
                        std.debug.print("Error dispatching close: {}\n", .{e});
                    };
                }

                c.PostQuitMessage(0);
                return 0;
            },

            c.WM_KEYDOWN => {
                // Fire events
                if (window_instance) |win| {
                    const key: key_code.KeyCode = key_code.keycodeFromInt(@intCast(wParam));

                    _ = win.app.event_system.window_events.on_key_pressed.dispatch(key) catch |e| {
                        std.debug.print("Error dispatching key: {}\n", .{e});
                    };
                }

                return 0;
            },

            c.WM_SIZE => {
                if (window_instance) |win| {
                    const size: WindowSize = WindowSize.init(@intCast(lParam & 0xFFFF), @intCast((lParam >> 16) & 0xFFFF), window_state.windowStateFromCInt(@intCast(wParam)));

                    _ = win.app.event_system.window_events.on_window_resize.dispatch(size) catch |e| {
                        std.debug.print("Error dispatching resize: {}\n", .{e});
                    };
                }

                return 0;
            },

            c.WM_MOUSEMOVE => {
                if (window_instance) |win| {
                    const position: MousePosition = MousePosition.init(@intCast(lParam & 0xFFFF), @intCast((lParam >> 16) & 0xFFFF));

                    _ = win.app.event_system.window_events.on_mouse_move.dispatch(position) catch |e| {
                        std.debug.print("Error dispatching mouse move: {}\n", .{e});
                    };
                }

                return 0;
            },

            c.WM_SETFOCUS => {
                if (window_instance) |win| {
                    _ = win.app.event_system.window_events.on_window_focus_gain.dispatch({}) catch |e| {
                        std.debug.print("Error dispatching focus: {}\n", .{e});
                    };
                }

                return 0;
            },

            c.WM_KILLFOCUS => {
                if (window_instance) |win| {
                    _ = win.app.event_system.window_events.on_window_focus_lose.dispatch({}) catch |e| {
                        std.debug.print("Error dispatching focus: {}\n", .{e});
                    };
                }

                return 0;
            },

            else => return c.DefWindowProcA(hwnd, uMsg, wParam, lParam),
        }
    }

    /// Sets up the OpenGL context
    fn setupWindowsOpenGLContext(hwnd: HWND, width: i16, height: i16) c.HDC {
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

        // Enable depth testing
        c.glEnable(c.GL_DEPTH_TEST);

        // Camera setup
        const f_width: f64 = @floatFromInt(width);
        const f_height: f64 = @floatFromInt(height);

        c.glMatrixMode(c.GL_PROJECTION);
        c.glLoadIdentity();
        _ = c.gluPerspective(45.0, f_width / f_height, 0.1, 100.0);
        c.glMatrixMode(c.GL_MODELVIEW);

        return hdc;
    }

    /// Returns the middle position for the window
    fn getMiddleXYPostionForWindow(window_width: i32, window_height: i32) ScreenPosition {
        const screen_width: c_int = c.GetSystemMetrics(c.SM_CXSCREEN);
        const screen_height: c_int = c.GetSystemMetrics(c.SM_CYSCREEN);

        return ScreenPosition{
            .x = @divTrunc(screen_width - window_width, 2),
            .y = @divTrunc(screen_height - window_height, 2),
        };
    }
};

const ScreenPosition = struct { x: i32, y: i32 };
