const std = @import("std");
const c = @cImport({
    @cInclude("windows.h");
});

const eventDispatcher = @import("../utils/event_dispatcher.zig");
const EventDispatcher = eventDispatcher.EventDispatcher;
const KeyCode = eventDispatcher.KeyCode;
const keycodeFromInt = eventDispatcher.keycodeFromInt;

// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
// TYPES
// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
const HWND = c.HWND;
const WNDCLASS = c.WNDCLASS;

const Const_Allocator = *const std.mem.Allocator;

// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
// STRUCT
// ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
pub const Window = struct {
    pga: Const_Allocator, // ptr
    hwnd: HWND, // c_ptr

    keyboard_dispatcher: *EventDispatcher(KeyCode),

    pub fn init(keyboard_dispatcher: *EventDispatcher(KeyCode), window_title: [*]const u8, width: i16, height: i16) !*Window {
        const pga = std.heap.page_allocator;
        const class_name: [*c]const u8 = "GlazeWindowClass";

        var wc: WNDCLASS = .{};
        wc.lpfnWndProc = WindowProc;
        wc.lpszClassName = class_name;
        wc.hInstance = c.GetModuleHandleA(null);
        wc.hbrBackground = c.CreateSolidBrush(0x00000000);

        _ = c.RegisterClassA(&wc);

        const hwnd: HWND = c.CreateWindowExA(0, class_name, window_title, c.WS_OVERLAPPEDWINDOW, c.CW_USEDEFAULT, c.CW_USEDEFAULT, width, height, null, null, wc.hInstance, null);

        // Create instance
        const w_instance = try pga.create(Window);
        w_instance.* = Window{ .pga = &pga, .hwnd = hwnd, .keyboard_dispatcher = keyboard_dispatcher };

        // Store window instance in HWND
        _ = c.SetWindowLongPtrA(hwnd, c.GWLP_USERDATA, @intCast(@intFromPtr(w_instance)));

        return w_instance;
    }

    pub fn show(self: *Window) void {
        if (self.hwnd != null) {
            _ = c.ShowWindow(self.hwnd, c.SW_SHOW);
        } else {
            std.debug.print("Failed to show window: hwnd is NULL", .{});
        }
    }

    pub fn run(_: *Window) void {
        var msg: c.MSG = undefined;

        while (true) {
            const ret = c.GetMessageA(&msg, null, 0, 0);
            if (ret <= 0) break;
            _ = c.TranslateMessage(&msg);
            _ = c.DispatchMessageA(&msg);
        }
    }

    pub fn WindowProc(hwnd: c.HWND, uMsg: c.UINT, wParam: c.WPARAM, lParam: c.LPARAM) callconv(.c) c.LRESULT {
        // Get window instance ptr from HWND
        const window_long_ptr: usize = @intCast(c.GetWindowLongPtrA(hwnd, c.GWLP_USERDATA));
        const w_instance_ptr: ?*Window = @ptrFromInt(window_long_ptr);

        switch (uMsg) {
            c.WM_DESTROY => {
                c.PostQuitMessage(0);
                return 0;
            },
            c.WM_KEYDOWN => {
                // Dispatch event to event dispatcher if window instance exists
                if (w_instance_ptr) |win| {
                    const key: KeyCode = keycodeFromInt(@intCast(wParam));
                    _ = win.keyboard_dispatcher.dispatch(key) catch |e| {
                        std.debug.print("Error dispatching key: {}\n", .{e});
                    };
                }

                return 0;
            },
            else => return c.DefWindowProcA(hwnd, uMsg, wParam, lParam),
        }
    }
};
