const std = @import("std");
const GLContext = @import("gl-context.zig").GlContext;
const Event = @import("../event-system/event_dispatcher.zig").EventDispatcher(void);

pub const Window = struct {
    gl_context: *GLContext,
    on_request_frame: *Event,

    width: c_int,
    height: c_int,

    pub fn deinit(self: *Window) void {
        self.gl_context.destroy();
        self.on_request_frame.deinit();
    }
};
