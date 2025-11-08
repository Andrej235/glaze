const Length = @import("values/length.zig").Length;
const Display = @import("values/display.zig").Display;
const Color = @import("values/color.zig").Color;

pub const Style = struct {
    display: ?Display = null,

    top: ?Length = null,
    right: ?Length = null,
    bottom: ?Length = null,
    left: ?Length = null,

    width: ?Length = null,
    height: ?Length = null,

    margin_top: ?Length = null,
    margin_right: ?Length = null,
    margin_bottom: ?Length = null,
    margin_left: ?Length = null,

    padding_top: ?Length = null,
    padding_right: ?Length = null,
    padding_bottom: ?Length = null,
    padding_left: ?Length = null,

    background_color: ?Color = null,
};
