const std = @import("std");

const TagType = enum {
    opening,
    closing,
    self_closing,
    unknown,
};

const OpeningTag = struct {
    start: u32,
    end: u32,

    name_start: u32,
    name_end: u32,

    attributes: ?std.ArrayList(Attribute),
};

const SelfClosingTag = struct {
    start: u32,
    end: u32,

    name_start: u32,
    name_end: u32,

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

    name_start: u32,
    name_end: u32,
};

const Token = union(enum) {
    openingTag: OpeningTag,
    closingTag: ClosingTag,
    selfClosingTag: SelfClosingTag,

    pub fn createOpeningTag(start: u32, end: u32, name_start: u32, name_end: u32, attributes: ?std.ArrayList(Attribute)) Token {
        return Token{
            .openingTag = OpeningTag{
                .start = start,
                .end = end,

                .name_start = name_start,
                .name_end = name_end,

                .attributes = attributes,
            },
        };
    }

    pub fn createSelfClosingTag(start: u32, end: u32, name_start: u32, name_end: u32, attributes: ?std.ArrayList(Attribute)) Token {
        return Token{
            .selfClosingTag = SelfClosingTag{
                .start = start,
                .end = end,

                .name_start = name_start,
                .name_end = name_end,

                .attributes = attributes,
            },
        };
    }

    pub fn createClosingTag(start: u32, end: u32, name_start: u32, name_end: u32) Token {
        return Token{
            .closingTag = ClosingTag{
                .start = start,
                .end = end,

                .name_start = name_start,
                .name_end = name_end,
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
        std.debug.print("--- {s} ---\n", .{zxFilePath});

        var file = try cwd.openFile(zxFilePath, .{ .mode = .read_write });
        defer file.close();

        var content = try file.readToEndAlloc(allocator, 1024);

        const tags = try parseTags(&content);

        std.debug.print("Total: {}\n\n", .{tags.items.len});
        for (tags.items) |tag| {
            switch (tag) {
                .openingTag => {
                    const tag_name = content[tag.openingTag.name_start..tag.openingTag.name_end];
                    std.debug.print("open: {s}\n", .{tag_name});

                    if (tag.openingTag.attributes) |attrs| {
                        for (attrs.items) |attr| {
                            std.debug.print("   --> {s} | {s} | {s}\n", .{ attr.name, attr.value, @tagName(attr.type) });
                        }
                    }
                },
                .selfClosingTag => {
                    const tag_name = content[tag.selfClosingTag.name_start..tag.selfClosingTag.name_end];
                    std.debug.print("self closing: {s}\n", .{tag_name});

                    if (tag.selfClosingTag.attributes) |attrs| {
                        for (attrs.items) |attr| {
                            std.debug.print("   --> {s} | {s} | {s}\n", .{ attr.name, attr.value, @tagName(attr.type) });
                        }
                    }
                },
                .closingTag => {
                    const tag_name = content[tag.closingTag.name_start..tag.closingTag.name_end];
                    std.debug.print("closing: {s}\n", .{tag_name});
                },
            }

            std.debug.print("\n", .{});
        }

        std.debug.print("\n\n\n", .{});
    }
}

pub fn parseTags(buffer: *[]u8) !std.ArrayList(Token) {
    const allocator = std.heap.page_allocator;
    var tags = std.ArrayList(Token){};

    var current: u32 = 0;

    var start_marker: ?u32 = null;
    var name_start: ?u32 = null;
    var name_end: ?u32 = null;
    var end_marker: ?u32 = null;

    var tag_type: TagType = .unknown;

    while (current < buffer.len - 1) : (current += 1) {
        const current_char = buffer.*[current];

        if (start_marker == null) { //? start of a tag
            if (current_char == '<') {
                start_marker = current;
                continue;
            }

            continue;
        }

        if (name_start == null) { //? search for tag name
            if (isValidNameStartingChar(current_char)) // name must start with an alpha char or '_'
            {
                name_start = current;

                if (tag_type == .unknown)
                    tag_type = .opening;

                continue;
            }

            if (current_char == '/' and tag_type == .unknown) {
                tag_type = .closing;
                continue;
            }

            if (!std.ascii.isWhitespace(current_char)) { //? invalid tag, assume there was a random '<' char in the file
                std.debug.print("Invalid tag name, found '{s}'\n", .{[_]u8{current_char}});

                // cleanup
                start_marker = null;
                name_start = null;
                name_end = null;
                end_marker = null;
                tag_type = .unknown;

                continue;
            }

            continue; // whitespace
        }

        if (name_end == null) { //? search for the end of a tag name
            if (std.ascii.isWhitespace(current_char)) {
                name_end = current;
                continue;
            }

            if (current_char == '/' or current_char == '>') { // no whitespace between name and end marker
                name_end = current;
                current -= 1; // let the end marker search determine the type of the tag and take care of the cleanup
                continue;
            }

            if (!isValidNameChar(current_char)) {
                std.debug.print("Invalid tag name, found '{s}'\n", .{[_]u8{current_char}});
                return error.InvalidTagName;
            }

            continue; // valid name char
        }

        if (end_marker == null) { //? search for end of a tag{
            if (current_char == '/' and tag_type == .opening) {
                tag_type = .self_closing;
                continue;
            }

            if (current_char == '>') { //? end of tag
                end_marker = current;

                if (tag_type == .opening) {
                    const attrs = try parseAttributes(buffer, name_end.? + 1, end_marker.?);
                    tags.append(
                        allocator,
                        Token.createOpeningTag(
                            start_marker.?,
                            end_marker.?,
                            name_start.?,
                            name_end.?,
                            attrs,
                        ),
                    ) catch return error.AllocationError;
                }

                if (tag_type == .self_closing) {
                    const attrs = try parseAttributes(
                        buffer,
                        name_end.? + 1,
                        if (tag_type == .self_closing) end_marker.? - 1 else end_marker.?,
                    );
                    tags.append(
                        allocator,
                        Token.createSelfClosingTag(
                            start_marker.?,
                            end_marker.?,
                            name_start.?,
                            name_end.?,
                            attrs,
                        ),
                    ) catch return error.AllocationError;
                }

                if (tag_type == .closing) {
                    tags.append(
                        allocator,
                        Token.createClosingTag(
                            start_marker.?,
                            end_marker.?,
                            name_start.?,
                            name_end.?,
                        ),
                    ) catch return error.AllocationError;
                }

                // cleanup
                start_marker = null;
                name_start = null;
                name_end = null;
                end_marker = null;
                tag_type = .unknown;

                continue;
            }

            if (tag_type == .closing and !std.ascii.isWhitespace(current_char)) { //? closing tags can't have attributes, so only whitespace is allowed
                std.debug.print("Invalid tag name, found '{s}'\n", .{[_]u8{current_char}});
                return error.InvalidAttributeName;
            }

            continue;
        }
    }

    return tags;
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
