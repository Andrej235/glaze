const Length = @import("values/length.zig").Length;
const Display = @import("values/display.zig").Display;
const Color = @import("values/color.zig").Color;
const Position = @import("values/position.zig").Position;

pub const Style = struct {
    display: Display = .block,

    position: Position = .unset,
    top: ?Length = null,
    right: ?Length = null,
    bottom: ?Length = null,
    left: ?Length = null,

    width: ?Length = null,
    height: ?Length = null,

    margin: ?[4]Length = null,
    padding: ?[4]Length = null,

    background_color: ?Color = null,
};
