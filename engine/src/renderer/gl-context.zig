pub const GlContext = struct {
    make_current: *const fn (*GlContext) anyerror!void,
    swap_buffers: *const fn (*GlContext) anyerror!void,
    get_proc_address: *const fn (*GlContext, [*]const u8) ?*anyopaque,
    destroy: *const fn (*GlContext) void,

    data: *anyopaque,
};
