const std = @import("std");
const Gl = @import("gl/gl.zig").Gl;
const Event = @import("../event-system/event_dispatcher.zig").EventDispatcher(void, *anyopaque);

pub const Window = struct {
    gl: *Gl,
    on_request_frame: *Event,

    width: i32,
    height: i32,

    pub fn deinit(self: *Window) void {
        self.gl.destroy();
        self.on_request_frame.deinit();
    }
};
