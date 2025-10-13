const std = @import("std");

const c = @cImport({
    @cInclude("../src/renderer/gl/glad/include/glad/gl.h");
});

pub const Material = struct {
    program: c.GLuint,
    vertex_shader: c.GLuint,
    fragment_shader: c.GLuint,

    pub fn create(vertex_src: [:0]const u8, fragment_src: [:0]const u8) !*Material {
        std.debug.print("Compiling material\n", .{});
        const vs = try compile_shader(c.GL_VERTEX_SHADER, vertex_src);
        const fs = try compile_shader(c.GL_FRAGMENT_SHADER, fragment_src);

        const prog = c.glCreateProgram();
        c.glAttachShader(prog, vs);
        c.glAttachShader(prog, fs);
        c.glLinkProgram(prog);

        var success: c.GLint = 0;
        c.glGetProgramiv(prog, c.GL_LINK_STATUS, &success);
        if (success == 0) {
            var buf: [512]u8 = undefined;
            var len: c.GLsizei = 0;
            c.glGetProgramInfoLog(prog, buf.len, &len, &buf);
            std.debug.print("Program link failed: {s}\n", .{buf[0..@intCast(len)]});
            return error.ProgramLinkFailed;
        }

        const material = try std.heap.c_allocator.create(Material);
        material.* = Material{
            .program = prog,
            .vertex_shader = vs,
            .fragment_shader = fs,
        };

        return material;
    }

    fn compile_shader(kind: c.GLenum, source: [:0]const u8) !c.GLuint {
        const shader = c.glCreateShader(kind);
        const srcs = [_][*:0]const u8{source};
        c.glShaderSource(shader, 1, &srcs, null);
        c.glCompileShader(shader);

        var success: c.GLint = 0;
        c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &success);
        if (success == 0) {
            var buf: [512]u8 = undefined;
            var len: c.GLsizei = 0;
            c.glGetShaderInfoLog(shader, buf.len, &len, &buf);
            std.debug.print("Shader compile failed: {s}\n", .{buf[0..@intCast(len)]});
            return error.ShaderCompileFailed;
        }
        return shader;
    }
};
