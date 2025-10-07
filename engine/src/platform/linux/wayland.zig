const std = @import("std");
const Window = @import("../../renderer/window.zig").Window;

const c = @cImport({
    @cInclude("wayland-client.h");
    @cInclude("wayland-egl.h");
    @cInclude("EGL/egl.h");
    @cInclude("GLES2/gl2.h");
    @cInclude("xkbcommon/xkbcommon.h");
    @cInclude("wayland/xdg-shell-client-protocol.h");
});

pub const Wayland = struct {
    pub fn init_window() anyerror!Window {
        return error.Unimplemented;
    }
};
