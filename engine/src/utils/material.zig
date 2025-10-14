const std = @import("std");

const zigimg = @import("zigimg");

const c = @cImport({
    @cInclude("../src/renderer/gl/glad/include/glad/gl.h");
});

pub const Material = struct {
    program: c.GLuint,

    position_attribute_location: i32,
    texture_attribute_location: i32,
    model_matrix_uniform_location: i32,
    projection_matrix_uniform_location: i32,
    texture_uniform_location: i32,

    texture: ?c.GLuint = null,
    cached_image: ?*zigimg.Image = null,
    cached_image_path: ?[]const u8 = null,

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
        const tex_loc = c.glGetUniformLocation(program, "u_Texture");

        const material = try std.heap.c_allocator.create(Material);
        material.* = Material{
            .program = program,
            .position_attribute_location = pos_attr,
            .texture_attribute_location = tex_attr,
            .model_matrix_uniform_location = model_loc,
            .projection_matrix_uniform_location = proj_loc,
            .texture_uniform_location = tex_loc,
        };

        return material;
    }

    pub fn loadTexture(self: *Material, path: []const u8) !void {
        if (self.cached_image_path != null and std.mem.eql(u8, self.cached_image_path.?, path)) return;

        const allocator = std.heap.smp_allocator;
        if (self.cached_image) |img|
            img.deinit(allocator);

        var read_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
        const image: *zigimg.Image = allocator.create(zigimg.Image) catch unreachable;

        image.* = try zigimg.Image.fromFilePath(
            allocator,
            path,
            read_buffer[0..],
        );

        try image.convert(allocator, .rgba32);
        const pixels = image.pixels.asBytes();
        const width = image.width;
        const height = image.height;

        var tex: c.GLuint = 0;
        c.glGenTextures(1, &tex);
        c.glBindTexture(c.GL_TEXTURE_2D, tex);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
        c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, @intCast(width), @intCast(height), 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, pixels.ptr);
        c.glBindTexture(c.GL_TEXTURE_2D, 0);

        std.debug.print("Tex loaded\n", .{});
        self.texture = tex;
        self.cached_image = image;
        self.cached_image_path = path;
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
