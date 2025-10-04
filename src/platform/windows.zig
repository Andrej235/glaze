// ****************************************************************
// IMPORTS
// ****************************************************************
const std = @import("std");
const c = @cImport({
    @cInclude("windows.h");
});

const key_code = @import("../event-system/models/key_code.zig");
const window_state = @import("../event-system/models/window_state.zig");

const Window = @import("../ui/window.zig").Window;
const WindowSize = @import("../event-system/models/window_size.zig").WindowSize;

// ****************************************************************
// TYPES
// ****************************************************************
const HWND = c.HWND;
const WNDCLASS = c.WNDCLASS;

// ****************************************************************
// MAIN
// ****************************************************************
pub const PlatformWindow = struct {
    allocator_ptr: *std.heap.ArenaAllocator,
    window_ptr: *Window,

    hwnd_ptr: HWND,

    pub fn init(allocator_ptr: *std.heap.ArenaAllocator, window_ptr: *Window, window_title: []const u8, width: i16, height: i16) !PlatformWindow {
        const class_name: [*c]const u8 = "GlazeWindowClass";

        var wc: WNDCLASS = .{};
        wc.lpfnWndProc = WindowProc;
        wc.lpszClassName = class_name;
        wc.hInstance = c.GetModuleHandleA(null);
        wc.hbrBackground = c.CreateSolidBrush(0x00000000);

        _ = c.RegisterClassA(&wc);

        const hwnd: HWND = c.CreateWindowExA(0, class_name, &window_title[0], c.WS_OVERLAPPEDWINDOW, c.CW_USEDEFAULT, c.CW_USEDEFAULT, width, height, null, null, wc.hInstance, null);

        // Store window instance in HWND
        _ = c.SetWindowLongPtrA(hwnd, c.GWLP_USERDATA, @intCast(@intFromPtr(window_ptr)));

        // Create instance
        return PlatformWindow{ .allocator_ptr = allocator_ptr, .window_ptr = window_ptr, .hwnd_ptr = hwnd };
    }

    pub fn show(self: *PlatformWindow) !void {
        if (self.hwnd_ptr) |ptr| {
            _ = c.ShowWindow(ptr, c.SW_SHOW);
        } else {
            return error.NullPointer;
        }
    }

    pub fn run(_: *PlatformWindow) void {
        var msg: c.MSG = undefined;

        while (true) {
            const message_result = c.GetMessageA(&msg, null, 0, 0);

            // Possible message results:
            //    (message_result == 0) -> WM_QUIT
            //    (message_result == -1) -> error
            //    (message_result > 0) -> success
            if (message_result <= 0) break;

            // Translate virtual-key messages into character messages
            _ = c.TranslateMessage(&msg);

            // Send message to WindowProc function
            _ = c.DispatchMessageA(&msg);
        }
    }

    pub fn WindowProc(hwnd: c.HWND, uMsg: c.UINT, wParam: c.WPARAM, lParam: c.LPARAM) callconv(.c) c.LRESULT {
        // Get window instance ptr from HWND
        const window_long_ptr: usize = @intCast(c.GetWindowLongPtrA(hwnd, c.GWLP_USERDATA));
        const w_instance_ptr: ?*Window = @ptrFromInt(window_long_ptr);

        switch (uMsg) {
            c.WM_DESTROY => {
                // Fire events
                if (w_instance_ptr) |win| {
                    _ = win.window_events_ptr.on_window_destroy.dispatch({}) catch |e| {
                        std.debug.print("Error dispatching destroy: {}\n", .{e});
                    };
                }

                c.PostQuitMessage(0);
                return 0;
            },

            c.WM_CLOSE => {
                // Fire events
                if (w_instance_ptr) |win| {
                    _ = win.window_events_ptr.on_window_close.dispatch({}) catch |e| {
                        std.debug.print("Error dispatching close: {}\n", .{e});
                    };
                }

                c.PostQuitMessage(0);
                return 0;
            },

            c.WM_KEYDOWN => {
                // Fire events
                if (w_instance_ptr) |win| {
                    const key: key_code.KeyCode = key_code.keycodeFromInt(@intCast(wParam));

                    _ = win.window_events_ptr.on_key_pressed.dispatch(key) catch |e| {
                        std.debug.print("Error dispatching key: {}\n", .{e});
                    };
                }

                return 0;
            },

            c.WM_SIZE => {
                if (w_instance_ptr) |win| {
                    const size: WindowSize = WindowSize.init(@intCast(lParam & 0xFFFF), @intCast((lParam >> 16) & 0xFFFF), window_state.windowStateFromCInt(@intCast(wParam)));

                    _ = win.window_events_ptr.on_window_resize.dispatch(size) catch |e| {
                        std.debug.print("Error dispatching resize: {}\n", .{e});
                    };
                }

                return 0;
            },
            else => return c.DefWindowProcA(hwnd, uMsg, wParam, lParam),
        }
    }
};
