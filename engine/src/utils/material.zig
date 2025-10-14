const std = @import("std");

const c = @cImport({
    @cInclude("../src/renderer/gl/glad/include/glad/gl.h");
});

pub const Material = struct {
    program: c.GLuint,
    vertex_shader: c.GLuint,
    fragment_shader: c.GLuint,
    position_attribute_location: i32,
    texture_attribute_location: i32,
    model_matrix_uniform_location: i32,
    projection_matrix_uniform_location: i32,

    pub fn create(vertex_src: [:0]const u8, fragment_src: [:0]const u8) !*Material {
        std.debug.print("Compiling material\n", .{});
        const vs = try compile_shader(c.GL_VERTEX_SHADER, vertex_src);
        const fs = try compile_shader(c.GL_FRAGMENT_SHADER, fragment_src);

        const program = c.glCreateProgram();
        c.glAttachShader(program, vs);
        c.glAttachShader(program, fs);
        c.glLinkProgram(program);

        var success: c.GLint = 0;
        c.glGetProgramiv(program, c.GL_LINK_STATUS, &success);
        if (success == 0) {
            var buf: [512]u8 = undefined;
            var len: c.GLsizei = 0;
            c.glGetProgramInfoLog(program, buf.len, &len, &buf);
            std.debug.print("Program link failed: {s}\n", .{buf[0..@intCast(len)]});
            return error.ProgramLinkFailed;
        }

        const pos_attr = c.glGetAttribLocation(program, "a_Position");
        const tex_attr = c.glGetAttribLocation(program, "a_TexCoord");

        const model_loc = c.glGetUniformLocation(program, "u_Model");
        const proj_loc = c.glGetUniformLocation(program, "u_Projection");

        const material = try std.heap.c_allocator.create(Material);
        material.* = Material{
            .program = program,
            .vertex_shader = vs,
            .fragment_shader = fs,
            .position_attribute_location = pos_attr,
            .texture_attribute_location = tex_attr,
            .model_matrix_uniform_location = model_loc,
            .projection_matrix_uniform_location = proj_loc,
        };

        const stride = 4 * @sizeOf(f32);

        c.glEnableVertexAttribArray(@intCast(material.position_attribute_location));
        c.glVertexAttribPointer(@intCast(material.position_attribute_location), 2, c.GL_FLOAT, c.GL_FALSE, stride, null);

        c.glEnableVertexAttribArray(@intCast(material.texture_attribute_location));
        c.glVertexAttribPointer(@intCast(material.texture_attribute_location), 2, c.GL_FLOAT, c.GL_FALSE, stride, @ptrFromInt(@sizeOf(f32) * 2));

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
