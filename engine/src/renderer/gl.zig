const std = @import("std");

const GlContext = @import("gl-context.zig").GlContext;

const c = @cImport({
    @cInclude("GLES2/gl2.h"); // only for GL constants and types
});

pub const Gl = struct {
    context: *GlContext,

    pub fn init(ctx: *GlContext) !Gl {
        try ctx.load_glad(ctx);

        const self = Gl{
            .context = ctx,
        };
        return self;
    }

    pub fn destroy(_: *Gl) void {}
};
