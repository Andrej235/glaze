pub const GlContext = struct {
    swapBuffers: *const fn (*GlContext) anyerror!void,
    loadGlad: *const fn (*GlContext) anyerror!void,
    destroy: *const fn (*GlContext) void,

    data: *anyopaque,
};
