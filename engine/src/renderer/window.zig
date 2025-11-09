const std = @import("std");
const Gl = @import("gl/gl.zig").Gl;
const Event = @import("../event-system/event-dispatcher.zig").EventDispatcher(void, *anyopaque);

pub const Window = struct {
    gl: *Gl,
    on_request_frame: *Event,

    width: i32,
    height: i32,

    root_font_size: f32 = 16.0,

    pub fn deinit(self: *Window) void {
        self.gl.destroy();
        self.on_request_frame.deinit();
    }
};
