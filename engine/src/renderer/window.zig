const std = @import("std");
const GL = @import("gl.zig").GL;
const Event = @import("../event-system/event_dispatcher.zig").EventDispatcher(void);

pub const Window = struct {
    gl: *GL,
    on_request_frame: *Event,

    width: c_int,
    height: c_int,

    pub fn deinit(self: *Window) void {
        self.gl.destroy();
        self.on_request_frame.deinit();
    }
};
