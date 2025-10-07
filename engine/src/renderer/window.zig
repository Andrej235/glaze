const std = @import("std");
const GLContext = @import("gl-context.zig").GlContext;
const Event = @import("../event-system/event_dispatcher.zig").EventDispatcher(void);

pub const Window = struct {
    gl_context: GLContext,
    on_request_frame: Event,

    pub fn init(gl_context: GLContext) Window {
        const allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

        return Window{
            .gl_context = gl_context,
            .on_request_frame = try Event.init(&allocator),
        };
    }

    pub fn deinit(self: *Window) void {
        self.gl_context.destroy();
        self.on_request_frame.deinit();
    }
};
