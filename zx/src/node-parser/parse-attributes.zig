const std = @import("std");
const Attribute = @import("./attribute.zig").Attribute;

const char_utils = @import("./char-utils.zig");
const isValidNameChar = char_utils.isValidNameChar;
const isValidNameStartingChar = char_utils.isValidNameStartingChar;

pub fn parseAttributes(buffer: *const []const u8, start: u32, end: u32) !std.ArrayList(Attribute) {
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
