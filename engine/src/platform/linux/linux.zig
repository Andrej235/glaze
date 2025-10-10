const Window = @import("../../renderer/window.zig").Window;
const Platform = @import("../../utils/platform.zig");

pub const Linux = struct {
    pub fn initWindow() anyerror!*Window {
        if (Platform.detectRenderer() == .wayland) return initWl();

        return initX11();
    }

    fn initWl() anyerror!*Window {
        return @import("wayland.zig").Wayland.initWindow();
    }

    fn initX11() anyerror!*Window {
        return @import("x11.zig").X11.initWindow();
    }
};
