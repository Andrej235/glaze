const std = @import("std");

const dynString = @import("utils/dyn_string.zig");
const DynString = dynString.DynString;
const CError = dynString.CError;

const window = @import("ui/window.zig");
const Window = window.Window;

pub fn main() !void {
    const w_instance: *Window = try Window.init("GG", 500, 500);

    w_instance.show();
    w_instance.run();
}
