const std = @import("std");

const OpeningTag = struct {
    start: u32,
    end: u32,
    attributes: std.ArrayList(Attribute),
};

const Attribute = struct {
    name: []const u8,
    value: []const u8,
};

const ClosingTag = struct {
    start: u32,
    end: u32,
};

const Token = union(enum) {
    openingTag: OpeningTag,
    closingTag: ClosingTag,

    pub fn createOpeningTag(start: u32, end: u32, attributes: std.ArrayList(Attribute)) Token {
        return Token{
            .openingTag = OpeningTag{
                .start = start,
                .end = end,
                .attributes = attributes,
            },
        };
    }

    pub fn createClosingTag(start: u32, end: u32) Token {
        return Token{
            .closingTag = ClosingTag{
                .start = start,
                .end = end,
            },
        };
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
    defer dir.close();

    var zxFiles = std.ArrayList([]const u8){};
    try findZxFiles(&dir, &zxFiles, ".");

    var cwd = std.fs.cwd();
    for (zxFiles.items) |zxFilePath| {
        var file = try cwd.openFile(zxFilePath, .{ .mode = .read_write });
        defer file.close();

        var content = try file.readToEndAlloc(allocator, 1024);
        var i: u32 = 0;
        const len = content.len;

        while (i <= len) : (i += 1) {
            const tag = findZxSyntax(&content, &i) catch break;

            switch (tag) {
                .openingTag => {
                    const tag_name = content[tag.openingTag.start..tag.openingTag.end];
                    std.debug.print("{s}\n", .{tag_name});
                    std.debug.print("attributes: {any}\n", .{tag.openingTag.attributes});
                },
                .closingTag => {
                    const tag_name = content[tag.closingTag.start..tag.closingTag.end];
                    std.debug.print("{s}\n", .{tag_name});
                },
            }
        }
    }
}

pub fn findZxSyntax(buffer: *[]u8, current: *u32) !Token {
    while (current.* < buffer.len) : (current.* += 1) {
        const c = buffer.*[current.*];
        if (c == '<') {
            current.* += 1;
            return parseTag(buffer, current) catch continue;
        }
    }

    return error.ParseError;
}

pub fn parseTag(buffer: *[]u8, start: *u32) !Token {
    var current = start.*;
    defer start.* = current;

    var is_closing = false;
    var attributes_start: ?u32 = null;
    const attrs = std.ArrayList(Attribute){};

    while (current < buffer.len - 1) : (current += 1) {
        const current_char = buffer.*[current];
        const next_char = buffer.*[current + 1];

        if (current_char == '/') {
            if (next_char == '>') //? end of a self closing tag
                return Token.createOpeningTag(start.*, attributes_start orelse current, attrs);

            if (start.* == current) //? start of a closing tag
            {
                is_closing = true;
                continue; //* continue in needed to skip the alphanumeric check
            }
        }

        if (current_char == '>') { //? end of a tag
            if (is_closing) //? end of a closing tag
                return Token.createClosingTag(start.* + 1, current);

            //? end of an opening tag
            return Token.createOpeningTag(start.*, attributes_start orelse current, attrs);
        }

        if (!std.ascii.isAlphanumeric(current_char) and attributes_start == null) {
            if (!std.ascii.isWhitespace(current_char) or is_closing) {
                std.debug.print("asd\n", .{});
                return error.ParseError;
            }

            // whitespace
            attributes_start = current + 1;
        }
    }

    return error.ParseError;
}

fn findZxFiles(dir: *std.fs.Dir, list: *std.ArrayList([]const u8), path: []const u8) !void {
    const allocator = std.heap.page_allocator;

    var it = dir.iterate();
    while (try it.next()) |curr| {
        const curr_path = try std.mem.concat(allocator, u8, &[_][]const u8{ path, "/", curr.name });

        switch (curr.kind) {
            .directory => {
                var new_dir = try dir.openDir(curr.name, .{ .iterate = true });
                defer new_dir.close();
                try findZxFiles(&new_dir, list, curr_path);
            },
            .file => {
                if (std.mem.endsWith(u8, curr.name, ".zx")) {
                    try list.append(allocator, curr_path);
                }
            },
            else => {},
        }
    }
}
