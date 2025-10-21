const c = @cImport({
    @cInclude("windows.h");
});

pub const WindowState = enum {
    Restored,
    Minimized,
    Maximized,
    Unknown,
};

pub fn windowStateFromCInt(num: c_int) WindowState {
    return switch (num) {
        0 => WindowState.Restored,
        1 => WindowState.Minimized,
        2 => WindowState.Maximized,
        else => WindowState.Unknown,
    };
}
