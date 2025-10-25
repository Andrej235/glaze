const std = @import("std");

const OpeningTag = struct {
    start: u32,
    end: u32,
    attributes: ?std.ArrayList(Attribute),
};

const Attribute = struct {
    name: []const u8,
    value: []const u8,
    type: Type,

    const Type = enum { string, dynamic };

    pub fn create(name: []const u8, value: []const u8, attr_type: Type) Attribute {
        return Attribute{ .name = name, .value = value, .type = attr_type };
    }
};

const ClosingTag = struct {
    start: u32,
    end: u32,
};

const Token = union(enum) {
    openingTag: OpeningTag,
    closingTag: ClosingTag,

    pub fn createOpeningTag(start: u32, end: u32, attributes: ?std.ArrayList(Attribute)) Token {
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
            const res = try findZxSyntax(&content, &i);
            if (res) |tag| {
                switch (tag) {
                    .openingTag => {
                        const tag_name = content[tag.openingTag.start..tag.openingTag.end];
                        std.debug.print("{s}\n", .{tag_name});

                        if (tag.openingTag.attributes) |attrs| {
                            for (attrs.items) |attr| {
                                std.debug.print("   --> {s} | {s} | {s}\n", .{ attr.name, attr.value, @tagName(attr.type) });
                            }
                        }
                    },
                    .closingTag => {
                        const tag_name = content[tag.closingTag.start..tag.closingTag.end];
                        std.debug.print("{s}\n", .{tag_name});
                    },
                }
            }
        }
    }
}

pub fn findZxSyntax(buffer: *[]u8, current: *u32) !?Token {
    while (current.* < buffer.len) : (current.* += 1) {
        const c = buffer.*[current.*];
        if (c == '<') {
            current.* += 1;
            return try parseTag(buffer, current);
        }
    }

    return null;
}

pub fn parseTag(buffer: *[]u8, start: *u32) !Token {
    var current = start.*;
    defer start.* = current;

    var is_closing = false;
    var attributes_start: ?u32 = null;

    while (current < buffer.len - 1) : (current += 1) {
        const current_char = buffer.*[current];
        const next_char = buffer.*[current + 1];

        if (current_char == '/') {
            if (next_char == '>') //? end of a self closing tag
            {
                const attrs = if (attributes_start) |s| try parseAttributes(buffer, s, current) else null;

                return Token.createOpeningTag(
                    start.*,
                    attributes_start orelse current,
                    attrs,
                );
            }

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
            {
                const attrs = if (attributes_start) |s| try parseAttributes(buffer, s, current) else null;

                return Token.createOpeningTag(
                    start.*,
                    attributes_start orelse current,
                    attrs,
                );
            }
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

// Plan: search for alpha char, equal sign, brace, closing brace, repeat
pub fn parseAttributes(buffer: *[]u8, start: u32, end: u32) !std.ArrayList(Attribute) {
    const allocator = std.heap.page_allocator;
    var attrs = std.ArrayList(Attribute){};

    var current = start;

    var name_start: ?u32 = null;
    var name_end: ?u32 = null;

    var value_start: ?u32 = null;

    while (current < end) : (current += 1) {
        const current_char = buffer.*[current];

        if (name_start == null) { //? search for attribute name
            if (isValidNameStartingChar(current_char)) // name must start with an alpha char
            {
                name_start = current;
                continue;
            }

            if (!std.ascii.isWhitespace(current_char)) {
                std.debug.print("Invalid attribute name, found '{s}'\n", .{[_]u8{current_char}});
                return error.InvalidAttributeName;
            }

            continue;
        }

        if (name_end == null) { //? search for equal sign
            if (current_char == '=') {
                name_end = current;
                continue;
            }

            // between name and equal sign can only be whitespace (or alphanumeric chars but these are part of the name)
            if (!isValidNameChar(current_char) and !std.ascii.isWhitespace(current_char)) {
                std.debug.print("Invalid attribute name, found '{s}'\n", .{[_]u8{current_char}});
                return error.AttributeMissingValue;
            }

            continue;
        }

        if (value_start == null) { //? search for attribute value
            if (current_char == '{') {
                value_start = current;
                continue;
            }

            if (!std.ascii.isWhitespace(current_char))
                return error.InvalidAttributeValue;

            continue;
        }

        //? search for closing brace
        var open_brace_count: u32 = 1;

        while (open_brace_count > 0 and current < end) : (current += 1) {
            const char = buffer.*[current];

            if (char == '{') {
                open_brace_count += 1;
                continue;
            }

            if (char == '}') {
                open_brace_count -= 1;
                continue;
            }
        }

        if (open_brace_count > 0)
            return error.AttributeMissingClosingBrace;

        attrs.append(
            allocator,
            Attribute.create(
                buffer.*[name_start.?..name_end.?],
                buffer.*[value_start.? + 1 .. current - 1], // +1 and -1 are to remove the braces
                .dynamic,
            ),
        ) catch return error.AllocationError;

        name_start = null;
        name_end = null;
        value_start = null;
        current -= 1;
    }

    return attrs;
}

fn isValidNameStartingChar(c: u8) bool {
    return std.ascii.isAlphabetic(c) or c == '_';
}

fn isValidNameChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
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
