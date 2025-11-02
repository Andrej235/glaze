const std = @import("std");

const Font = @import("./font.zig").Font;

pub const FontManager = struct {
    fonts: std.StringHashMap(*Font),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) FontManager {
        return .{
            .fonts = std.StringHashMap(*Font).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn addFont(self: *FontManager, name: []const u8, atlasPath: []const u8, metaPath: []const u8) !void {
        const font = try self.allocator.create(Font);
        font.* = try Font.init(self.allocator, atlasPath, metaPath);
        try self.fonts.put(name, font);
    }

    pub fn getFont(self: *FontManager, name: []const u8) ?*Font {
        return self.fonts.get(name);
    }
};
