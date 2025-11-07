const Length = @import("values/length.zig").Length;

pub const Style = union(enum) {
    top: Length,
    right: Length,
    bottom: Length,
    left: Length,

    width: Length,
    height: Length,

    margin_top: Length,
    margin_right: Length,
    margin_bottom: Length,
    margin_left: Length,

    padding_top: Length,
    padding_right: Length,
    padding_bottom: Length,
    padding_left: Length,
};
