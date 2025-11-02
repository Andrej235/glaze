const std = @import("std");

const Renderer = @import("../renderer/renderer.zig").Renderer;
const Glyph = @import("./font-metadata.zig").Glyph;
const FontMetadata = @import("./font-metadata.zig").FontMetadata;

const c = @cImport({
    @cInclude("../src/renderer/gl/glad/include/glad/gl.h");
});

pub const Font = struct {
    atlasPath: []const u8,
    metaPath: []const u8,

    textureId: ?u32,
    metadata: FontMetadata,

    /// Simple lookup by unicode
    pub fn getGlyph(self: *Font, codepoint: u32) ?*Glyph {
        for (self.metadata.glyphs.items) |g| {
            if (g.unicode == codepoint) return &g;
        }
        return null;
    }

    pub fn getAtlasTexture(self: *Font) !u32 {
        if (self.textureId) |id|
            return id;

        self.textureId = try Renderer.cacheAtlasTexture(self.atlasPath);
        return self.textureId.?;
    }

    /// Initialize a Font from atlas PNG and JSON metadata paths
    pub fn init(allocator: std.mem.Allocator, atlasPath: []const u8, metaPath: []const u8) !Font {
        // Load JSON metadata
        var meta_file = try std.fs.cwd().openFile(metaPath, .{});
        defer meta_file.close();

        const meta_content = try meta_file.readToEndAlloc(allocator, 1024 * 1024); // 1mb should be enough
        defer allocator.free(meta_content);

        const parsed_metadata = try std.json.parseFromSlice(FontMetadata, allocator, meta_content, .{ .ignore_unknown_fields = true });
        const metadata = @as(FontMetadata, parsed_metadata.value);

        for (metadata.glyphs) |*glyph| {
            // Precompute normalized UVs
            if (glyph.atlasBounds) |atlasBounds| {
                glyph.uvBounds = .{
                    .top = atlasBounds.top / @as(f32, @floatFromInt(metadata.atlas.height)),
                    .right = atlasBounds.right / @as(f32, @floatFromInt(metadata.atlas.width)),
                    .bottom = atlasBounds.bottom / @as(f32, @floatFromInt(metadata.atlas.height)),
                    .left = atlasBounds.left / @as(f32, @floatFromInt(metadata.atlas.width)),
                };
            } else {
                glyph.uvBounds = .{
                    .top = 0,
                    .right = 0,
                    .bottom = 0,
                    .left = 0,
                };
            }
        }

        return Font{
            .atlasPath = atlasPath,
            .metaPath = metaPath,

            .textureId = null,
            .metadata = metadata,
        };
    }
};
