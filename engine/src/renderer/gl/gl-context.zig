pub const GlContext = struct {
    make_current: *const fn (*GlContext) anyerror!void,
    swap_buffers: *const fn (*GlContext) anyerror!void,
    load_glad: *const fn (*GlContext) anyerror!void,
    destroy: *const fn (*GlContext) void,

    data: *anyopaque,
};
