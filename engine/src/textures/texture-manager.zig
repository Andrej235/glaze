const std = @import("std");

const zigimg = @import("zigimg");

const c = @cImport({
    @cInclude("../src/renderer/gl/glad/include/glad/gl.h");
});

pub const TextureManager = struct {
    textures: std.StringHashMap(c.GLuint),

    pub fn init() TextureManager {
        return .{
            .textures = std.StringHashMap(c.GLuint).init(std.heap.page_allocator),
        };
    }

    fn pathHash(path: []const u8) u64 {
        return std.hash.Wyhash.hash(0, path);
    }

    pub fn getOrLoad(self: *TextureManager, path: []const u8) !c.GLuint {
        if (self.textures.get(path)) |tex| {
            return tex;
        }

        const allocator = std.heap.smp_allocator;
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

        self.textures.put(path, tex) catch unreachable;
        return tex;
    }
};
