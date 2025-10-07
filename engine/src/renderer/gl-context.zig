pub const GlContext = struct {
    make_current: fn (*GlContext) anyerror!void,
    swap_buffers: fn (*GlContext) void,
    get_proc_address: fn (*GlContext, [*]const u8) ?*anyopaque,
    destroy: fn (*GlContext) void,
};
