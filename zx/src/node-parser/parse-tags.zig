const std = @import("std");
const Token = @import("./tokens.zig").Token;
const TagType = @import("./tokens.zig").TagType;

const char_utils = @import("./char-utils.zig");
const isValidNameChar = char_utils.isValidNameChar;
const isValidNameStartingChar = char_utils.isValidNameStartingChar;

const parseAttributes = @import("./parse-attributes.zig").parseAttributes;

pub fn parseTags(buffer: *[]u8) !std.ArrayList(Token) {
    const allocator = std.heap.page_allocator;
    var tags = std.ArrayList(Token){};

    var current: u32 = 0;

    var start_marker: ?u32 = null;
    var name_start: ?u32 = null;
    var name_end: ?u32 = null;
    var end_marker: ?u32 = null;

    var tag_type: TagType = .unknown;

    var text_start: ?u32 = null;
    var dynamic_start: ?u32 = null;
    var open_tags: u32 = 0;

    while (current < buffer.len - 1) : (current += 1) {
        const current_char = buffer.*[current];

        if (start_marker == null) { //? start of a tag
            if (current_char == '<') {
                start_marker = current;

                if (text_start != null) { //? end of a text node
                    tags.append(allocator, Token.createTextToken(text_start.?, current)) catch return error.AllocationError;
                    text_start = null;
                }

                continue;
            }

            if (open_tags > 0 and dynamic_start == null) { //? in between open and close tags, look for text nodes
                if (std.ascii.isWhitespace(current_char)) // ignore whitespace at the start of a text node
                    continue;

                if (current_char == '{') {
                    dynamic_start = current + 1;

                    if (text_start != null) { //? end of a text node
                        tags.append(allocator, Token.createTextToken(text_start.?, current)) catch return error.AllocationError;
                        text_start = null;
                    }
                    continue;
                }

                if (text_start == null)
                    text_start = current;
                continue;
            }

            if (dynamic_start != null) {
                if (current_char == '}') {
                    tags.append(allocator, Token.createDynamicToken(dynamic_start.?, current)) catch return error.AllocationError;
                    dynamic_start = null;
                    continue;
                }
            }

            continue;
        }

        if (text_start != null and dynamic_start != null)
            continue;

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

            if (!isValidNameChar(current_char)) { //? probably just a random '<' char followed with whitespace and letters, not an actual tag
                std.debug.print("Invalid tag name, found '{s}'\n", .{[_]u8{current_char}});

                // cleanup
                start_marker = null;
                name_start = null;
                name_end = null;
                end_marker = null;
                tag_type = .unknown;
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

                    open_tags += 1;
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

                    open_tags -= 1;
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

    if (open_tags != 0) {
        std.debug.print("Missing closing tag\n", .{});
        return error.MissingClosingTag;
    }

    return tags;
}
