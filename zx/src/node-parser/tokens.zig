const std = @import("std");
const Attribute = @import("./attribute.zig").Attribute;

pub const TagType = enum {
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

    attributes: std.ArrayList(Attribute),
};

const SelfClosingTag = struct {
    start: u32,
    end: u32,

    name_start: u32,
    name_end: u32,
    
    attributes: std.ArrayList(Attribute),
};

const ClosingTag = struct {
    start: u32,
    end: u32,

    name_start: u32,
    name_end: u32,
};

const TextToken = struct {
    start_location: u32,
    end_location: u32,
};

const DynamicToken = struct {
    start_location: u32,
    end_location: u32,
};

pub const Token = union(enum) {
    opening_tag: OpeningTag,
    closing_tag: ClosingTag,
    self_closing_tag: SelfClosingTag,
    text: TextToken,
    dynamic: DynamicToken,

    pub fn createOpeningTag(start: u32, end: u32, name_start: u32, name_end: u32, attributes: std.ArrayList(Attribute)) Token {
        return Token{
            .opening_tag = OpeningTag{
                .start = start,
                .end = end,

                .name_start = name_start,
                .name_end = name_end,

                .attributes = attributes,
            },
        };
    }

    pub fn createSelfClosingTag(start: u32, end: u32, name_start: u32, name_end: u32, attributes: std.ArrayList(Attribute)) Token {
        return Token{
            .self_closing_tag = SelfClosingTag{
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
            .closing_tag = ClosingTag{
                .start = start,
                .end = end,

                .name_start = name_start,
                .name_end = name_end,
            },
        };
    }

    pub fn createTextToken(start: u32, end: u32) Token {
        return Token{
            .text = TextToken{
                .start_location = start,
                .end_location = end,
            },
        };
    }

    pub fn createDynamicToken(start: u32, end: u32) Token {
        return Token{
            .dynamic = DynamicToken{
                .start_location = start,
                .end_location = end,
            },
        };
    }
};
