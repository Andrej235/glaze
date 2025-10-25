const std = @import("std");

pub fn isValidNameStartingChar(c: u8) bool {
    return std.ascii.isAlphabetic(c) or c == '_';
}

pub fn isValidNameChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '_';
}
