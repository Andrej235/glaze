const c = @cImport({
    @cInclude("windows.h");
});

pub const KeyCode = enum(c.WPARAM) {
    A = @intCast(0x41),
    W = @intCast(0x57),
    S = @intCast(0x53),
    D = @intCast(0x44),
    Unknown = @intCast(0),
};

pub fn keycodeFromInt(num: u32) KeyCode {
    return switch (num) {
        0x41 => KeyCode.A,
        0x57 => KeyCode.W,
        0x53 => KeyCode.S,
        0x44 => KeyCode.D,
        else => KeyCode.Unknown,
    };
}
