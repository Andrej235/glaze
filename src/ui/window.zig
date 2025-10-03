// ****************************************************************
// IMPORTS
// ****************************************************************
const std = @import("std");
const c = @cImport({
    @cInclude("windows.h");
});

const eventDispatcher = @import("../event-system/event_dispatcher.zig");
const EventDispatcher = eventDispatcher.EventDispatcher;

const key_code = @import("../event-system/models/key_code.zig");
const KeyCode = key_code.KeyCode;
const keycodeFromInt = key_code.keycodeFromInt;

const window_events = @import("../event-system/events/window_events.zig");
const WindowEvents = window_events.WindowEvents;

const event_manager = @import("../event-system/event_manager.zig");
const EventManager = event_manager.EventManager;

// ****************************************************************
// TYPES
// ****************************************************************
const HWND = c.HWND;
const WNDCLASS = c.WNDCLASS;

const Const_Allocator = *const std.mem.Allocator;

// ****************************************************************
// MAIN
// ****************************************************************
pub const Window = struct {
    allocator: Const_Allocator, // ptr
    hwnd: HWND, // c_ptr

    window_events: *WindowEvents,

    pub fn init(window_title: [*]const u8, width: i16, height: i16) !*Window {
        const allocator = std.heap.page_allocator;
        const class_name: [*c]const u8 = "GlazeWindowClass";

        var wc: WNDCLASS = .{};
        wc.lpfnWndProc = WindowProc;
        wc.lpszClassName = class_name;
        wc.hInstance = c.GetModuleHandleA(null);
        wc.hbrBackground = c.CreateSolidBrush(0x00000000);

        _ = c.RegisterClassA(&wc);

        const hwnd: HWND = c.CreateWindowExA(0, class_name, window_title, c.WS_OVERLAPPEDWINDOW, c.CW_USEDEFAULT, c.CW_USEDEFAULT, width, height, null, null, wc.hInstance, null);

        // Create instance
        const window_events_ptr: *WindowEvents = (try event_manager.getEventManager()).getWindowEvents();

        const w_instance = try allocator.create(Window);
        w_instance.* = Window{ .allocator = &allocator, .hwnd = hwnd, .window_events = window_events_ptr };

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

                    _ = win.window_events.keyboard_dispatcher.dispatch(key) catch |e| {
                        std.debug.print("Error dispatching key: {}\n", .{e});
                    };
                }

                return 0;
            },
            else => return c.DefWindowProcA(hwnd, uMsg, wParam, lParam),
        }
    }
};
