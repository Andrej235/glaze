const KeyCode = @import("keycode.zig").KeyCode;
const c = @cImport({
    @cInclude("windows.h");
});

pub fn keycodeFromInt(code: c.WPARAM) KeyCode {
    return switch (code) {

        // Letters
        0x41 => .A,
        0x42 => .B,
        0x43 => .C,
        0x44 => .D,
        0x45 => .E,
        0x46 => .F,
        0x47 => .G,
        0x48 => .H,
        0x49 => .I,
        0x4A => .J,
        0x4B => .K,
        0x4C => .L,
        0x4D => .M,
        0x4E => .N,
        0x4F => .O,
        0x50 => .P,
        0x51 => .Q,
        0x52 => .R,
        0x53 => .S,
        0x54 => .T,
        0x55 => .U,
        0x56 => .V,
        0x57 => .W,
        0x58 => .X,
        0x59 => .Y,
        0x5A => .Z,

        // Digits
        0x30 => .Num0,
        0x31 => .Num1,
        0x32 => .Num2,
        0x33 => .Num3,
        0x34 => .Num4,
        0x35 => .Num5,
        0x36 => .Num6,
        0x37 => .Num7,
        0x38 => .Num8,
        0x39 => .Num9,

        // Function keys
        0x70 => .F1,
        0x71 => .F2,
        0x72 => .F3,
        0x73 => .F4,
        0x74 => .F5,
        0x75 => .F6,
        0x76 => .F7,
        0x77 => .F8,
        0x78 => .F9,
        0x79 => .F10,
        0x7A => .F11,
        0x7B => .F12,

        // Arrows
        0x26 => .Up,
        0x28 => .Down,
        0x25 => .Left,
        0x27 => .Right,

        // Other
        0x10 => .LeftShift,
        0x11 => .LeftCtrl,
        0x12 => .LeftAlt,
        0x14 => .CapsLock,
        0x09 => .Tab,
        0x1B => .Escape,
        0x20 => .Space,
        0x0D => .Enter,
        0x08 => .Backspace,
        0x2E => .Delete,

        else => .Unknown,
    };
}
