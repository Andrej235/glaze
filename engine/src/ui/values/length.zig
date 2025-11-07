const Keyword = @import("length-keywords.zig").LengthKeywords;

pub const Length = union(enum) {
    px: f32,
    em: f32,
    rem: f32,
    vw: f32,
    vh: f32,
    percent: f32,
    keyword: Keyword,
};
