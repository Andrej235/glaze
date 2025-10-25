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
            const tag = findZxSyntax(&content, &i) catch break;

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

pub fn parseAttributes(buffer: *[]u8, start: u32, end: u32) !std.ArrayList(Attribute) {
    const allocator = std.heap.page_allocator;
    var attrs = std.ArrayList(Attribute){};

    var current = start;

    var name_start: ?u32 = null;
    var name_end: ?u32 = null;

    var value_start: ?u32 = null;

    var enclosed = false;
    var enclosing_type: ?Attribute.Type = null;

    while (current < end) : (current += 1) {
        const current_char = buffer.*[current];

        if (current_char == '=') {
            if (value_start != null and !enclosed) //? multiple equal signs are never valid in this context
                return error.InvalidAttribute;

            // equal sign doesn't mean the start of a value but the end of the name, there could still be whitespace between the it and the value
            if (name_end == null) //? if name end is already set it means there was whitespace between the name and the equal sign, this is fine
                name_end = current;
            continue;
        }

        if (current_char == '"' and (!enclosed or buffer.*[current - 1] != '\\')) { //? attribute value is enclosed in double quotes
            if (enclosed) { //? end of attribute value and so the attribute is complete
                attrs.append(
                    allocator,
                    Attribute.create(
                        buffer.*[name_start.?..name_end.?],
                        buffer.*[value_start.?..current],
                        .string,
                    ),
                ) catch return error.AllocationError;

                // cleanup
                name_start = null;
                name_end = null;

                value_start = null;

                enclosed = false;
                enclosing_type = null;
                continue;
            }

            if (!enclosed) {
                enclosed = true;
                enclosing_type = .string;
                value_start = current + 1; // +1 is to skip the double quote
                continue;
            }
        }

        if (current_char == '{' and !enclosed) { //? attribute value is enclosed in curly braces
            enclosed = true;
            enclosing_type = .dynamic;
            value_start = current + 1; // +1 is to skip the brace
            continue;
        }

        if (current_char == '}' and enclosing_type.? == .dynamic) { //? end of attribute value and so the attribute is complete
            attrs.append(
                allocator,
                Attribute.create(
                    buffer.*[name_start.?..name_end.?],
                    buffer.*[value_start.?..current],
                    enclosing_type.?,
                ),
            ) catch return error.AllocationError;

            // cleanup
            name_start = null;
            name_end = null;

            value_start = null;

            enclosed = false;
            enclosing_type = null;

            continue;
        }

        if (std.ascii.isWhitespace(current_char) and name_start != null) { //? attribute without a value (no equal sign found) is considered a boolean with a value of true
            if (name_end == null) //? if name end is not already set it means we haven't encountered neither whitespace nor an equal sign already
                name_end = current;

            continue;
        }

        if (std.ascii.isAlphabetic(current_char)) {
            //? name start must be reset to null after each new attribute creation to ensure that whitespace at the end of a tag doesn't get it's own boolean value
            if (name_start == null) {
                name_start = current;
                continue;
            }

            //? we found whitespace after a name (or we are at the end of attributes buffer) but there was no equel sign before new text so this is a boolean with a value of true
            if (!enclosed and name_end != null) {
                attrs.append(
                    allocator,
                    Attribute.create(
                        buffer.*[name_start.?..name_end.?],
                        "true",
                        .dynamic,
                    ),
                ) catch return error.AllocationError;

                // cleanup
                name_start = current;
                name_end = null;

                value_start = null;

                enclosed = false;
                enclosing_type = null;
                continue;
            }
        }
    }

    if (name_start != null) {
        attrs.append(
            allocator,
            Attribute.create(
                buffer.*[name_start.? .. name_end orelse current],
                "true",
                .dynamic,
            ),
        ) catch return error.AllocationError;
    }

    return attrs;
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
