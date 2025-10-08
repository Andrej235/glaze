const std = @import("std");

const GlContext = @import("gl-context.zig").GlContext;

const c = @cImport({
    @cInclude("GLES2/gl2.h"); // only for GL constants and types
});

pub const GL = struct {
    // Commonly used GL function pointers
    glCreateShader: *const fn (c.GLenum) c.GLuint,
    glShaderSource: *const fn (c.GLuint, c.GLsizei, [*]const [*]const u8, ?[*]const c.GLint) void,
    glCompileShader: *const fn (c.GLuint) void,
    glGetShaderiv: *const fn (c.GLuint, c.GLenum, [*]c.GLint) void,
    glGetShaderInfoLog: *const fn (c.GLuint, c.GLsizei, [*]c.GLsizei, [*]u8) void,
    glDeleteShader: *const fn (c.GLuint) void,

    glCreateProgram: *const fn () c.GLuint,
    glAttachShader: *const fn (c.GLuint, c.GLuint) void,
    glBindAttribLocation: *const fn (c.GLuint, c.GLuint, [*:0]const u8) void,
    glLinkProgram: *const fn (c.GLuint) void,
    glGetProgramiv: *const fn (c.GLuint, c.GLenum, [*]c.GLint) void,
    glGetProgramInfoLog: *const fn (c.GLuint, c.GLsizei, [*]c.GLsizei, [*]u8) void,
    glUseProgram: *const fn (c.GLuint) void,
    glDeleteProgram: *const fn (c.GLuint) void,

    glClearColor: *const fn (f32, f32, f32, f32) void,
    glClear: *const fn (c.GLbitfield) void,
    glViewport: *const fn (c.GLint, c.GLint, c.GLsizei, c.GLsizei) void,

    glGenBuffers: *const fn (c.GLsizei, [*]c.GLuint) void,
    glBindBuffer: *const fn (c.GLenum, c.GLuint) void,
    glBufferData: *const fn (c.GLenum, isize, ?*const anyopaque, c.GLenum) void,
    glEnableVertexAttribArray: *const fn (c.GLuint) void,
    glVertexAttribPointer: *const fn (c.GLuint, c.GLint, c.GLenum, c.GLboolean, c.GLsizei, ?*const anyopaque) void,
    glDrawArrays: *const fn (c.GLenum, c.GLint, c.GLsizei) void,

    pub fn init(ctx: *GlContext) !GL {
        const self = GL{
            .glCreateShader = try load(ctx, "glCreateShader", *const fn (c.GLenum) c.GLuint),
            .glShaderSource = try load(ctx, "glShaderSource", *const fn (c.GLuint, c.GLsizei, [*]const [*]const u8, ?[*]const c.GLint) void),
            .glCompileShader = try load(ctx, "glCompileShader", *const fn (c.GLuint) void),
            .glGetShaderiv = try load(ctx, "glGetShaderiv", *const fn (c.GLuint, c.GLenum, [*]c.GLint) void),
            .glGetShaderInfoLog = try load(ctx, "glGetShaderInfoLog", *const fn (c.GLuint, c.GLsizei, [*]c.GLsizei, [*]u8) void),
            .glDeleteShader = try load(ctx, "glDeleteShader", *const fn (c.GLuint) void),

            .glCreateProgram = try load(ctx, "glCreateProgram", *const fn () c.GLuint),
            .glAttachShader = try load(ctx, "glAttachShader", *const fn (c.GLuint, c.GLuint) void),
            .glBindAttribLocation = try load(ctx, "glBindAttribLocation", *const fn (c.GLuint, c.GLuint, [*:0]const u8) void),
            .glLinkProgram = try load(ctx, "glLinkProgram", *const fn (c.GLuint) void),
            .glGetProgramiv = try load(ctx, "glGetProgramiv", *const fn (c.GLuint, c.GLenum, [*]c.GLint) void),
            .glGetProgramInfoLog = try load(ctx, "glGetProgramInfoLog", *const fn (c.GLuint, c.GLsizei, [*]c.GLsizei, [*]u8) void),
            .glUseProgram = try load(ctx, "glUseProgram", *const fn (c.GLuint) void),
            .glDeleteProgram = try load(ctx, "glDeleteProgram", *const fn (c.GLuint) void),

            .glClearColor = try load(ctx, "glClearColor", *const fn (f32, f32, f32, f32) void),
            .glClear = try load(ctx, "glClear", *const fn (c.GLbitfield) void),
            .glViewport = try load(ctx, "glViewport", *const fn (c.GLint, c.GLint, c.GLsizei, c.GLsizei) void),

            .glGenBuffers = try load(ctx, "glGenBuffers", *const fn (c.GLsizei, [*]c.GLuint) void),
            .glBindBuffer = try load(ctx, "glBindBuffer", *const fn (c.GLenum, c.GLuint) void),
            .glBufferData = try load(ctx, "glBufferData", *const fn (c.GLenum, isize, ?*const anyopaque, c.GLenum) void),
            .glEnableVertexAttribArray = try load(ctx, "glEnableVertexAttribArray", *const fn (c.GLuint) void),
            .glVertexAttribPointer = try load(ctx, "glVertexAttribPointer", *const fn (c.GLuint, c.GLint, c.GLenum, c.GLboolean, c.GLsizei, ?*const anyopaque) void),
            .glDrawArrays = try load(ctx, "glDrawArrays", *const fn (c.GLenum, c.GLint, c.GLsizei) void),
        };
        return self;
    }
};

fn load(ctx: *GlContext, name: [*:0]const u8, comptime T: type) !T {
    const addr = ctx.get_proc_address(ctx, name) orelse {
        std.debug.print("Failed to load {s}\n", .{name});
        return error.MissingGLFunction;
    };
    return @ptrCast(addr);
}
