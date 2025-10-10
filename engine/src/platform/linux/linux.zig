const Window = @import("../../renderer/window.zig").Window;
const Platform = @import("../../utils/platform.zig");

pub const Linux = struct {
    pub fn initWindow(width: u16, height: u16, window_title: [*:0]const u8) anyerror!*Window {
        if (Platform.detectRenderer() == .wayland) return initWl(width, height, window_title);

        return initX11();
    }

    fn initWl(width: u16, height: u16, window_title: [*:0]const u8) anyerror!*Window {
        return @import("wayland.zig").Wayland.initWindow(width, height, window_title);
    }

    fn initX11() anyerror!*Window {
        return @import("x11.zig").X11.initWindow();
    }
};
