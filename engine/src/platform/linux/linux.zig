const Window = @import("../../renderer/window.zig").Window;
const Platform = @import("../../utils/platform.zig");

pub const Linux = struct {
    pub fn init_window() anyerror!*Window {
        if (Platform.detectRenderer() == .wayland) return init_wl();

        return init_x11();
    }

    fn init_wl() anyerror!*Window {
        return @import("wayland.zig").Wayland.init_window();
    }

    fn init_x11() anyerror!*Window {
        return @import("x11.zig").X11.init_window();
    }
};
