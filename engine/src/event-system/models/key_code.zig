const c = @cImport({
    @cInclude("windows.h");
});

pub const KeyCode = enum(c.WPARAM) {
    // Letters
    A = @intCast(0x41),
    B = @intCast(0x42),
    C = @intCast(0x43),
    D = @intCast(0x44),
    E = @intCast(0x45),
    F = @intCast(0x46),
    G = @intCast(0x47),
    H = @intCast(0x48),
    I = @intCast(0x49),
    J = @intCast(0x4A),
    K = @intCast(0x4B),
    L = @intCast(0x4C),
    M = @intCast(0x4D),
    N = @intCast(0x4E),
    O = @intCast(0x4F),
    P = @intCast(0x50),
    Q = @intCast(0x51),
    R = @intCast(0x52),
    S = @intCast(0x53),
    T = @intCast(0x54),
    U = @intCast(0x55),
    V = @intCast(0x56),
    W = @intCast(0x57),
    X = @intCast(0x58),
    Y = @intCast(0x59),
    Z = @intCast(0x5A),

    // Digits
    Key0 = @intCast(0x30),
    Key1 = @intCast(0x31),
    Key2 = @intCast(0x32),
    Key3 = @intCast(0x33),
    Key4 = @intCast(0x34),
    Key5 = @intCast(0x35),
    Key6 = @intCast(0x36),
    Key7 = @intCast(0x37),
    Key8 = @intCast(0x38),
    Key9 = @intCast(0x39),

    // Function keys
    F1 = @intCast(0x70),
    F2 = @intCast(0x71),
    F3 = @intCast(0x72),
    F4 = @intCast(0x73),
    F5 = @intCast(0x74),
    F6 = @intCast(0x75),
    F7 = @intCast(0x76),
    F8 = @intCast(0x77),
    F9 = @intCast(0x78),
    F10 = @intCast(0x79),
    F11 = @intCast(0x7A),
    F12 = @intCast(0x7B),

    // Arrows
    Up = @intCast(0x26),
    Down = @intCast(0x28),
    Left = @intCast(0x25),
    Right = @intCast(0x27),

    // Modifiers
    Shift = @intCast(0x10),
    Ctrl = @intCast(0x11),
    Alt = @intCast(0x12),
    CapsLock = @intCast(0x14),
    Tab = @intCast(0x09),
    Escape = @intCast(0x1B),
    Space = @intCast(0x20),
    Enter = @intCast(0x0D),
    Backspace = @intCast(0x08),

    // Numpad
    Numpad0 = @intCast(0x60),
    Numpad1 = @intCast(0x61),
    Numpad2 = @intCast(0x62),
    Numpad3 = @intCast(0x63),
    Numpad4 = @intCast(0x64),
    Numpad5 = @intCast(0x65),
    Numpad6 = @intCast(0x66),
    Numpad7 = @intCast(0x67),
    Numpad8 = @intCast(0x68),
    Numpad9 = @intCast(0x69),
    Multiply = @intCast(0x6A),
    Add = @intCast(0x6B),
    Subtract = @intCast(0x6D),
    Decimal = @intCast(0x6E),
    Divide = @intCast(0x6F),

    // Symbols
    Semicolon = @intCast(0xBA),
    Equals = @intCast(0xBB),
    Comma = @intCast(0xBC),
    Minus = @intCast(0xBD),
    Period = @intCast(0xBE),
    Slash = @intCast(0xBF),
    Backtick = @intCast(0xC0),
    LeftBracket = @intCast(0xDB),
    Backslash = @intCast(0xDC),
    RightBracket = @intCast(0xDD),
    Quote = @intCast(0xDE),

    // Others
    Delete = @intCast(0x2E),
    Insert = @intCast(0x2D),
    Home = @intCast(0x24),
    End = @intCast(0x23),
    PageUp = @intCast(0x21),
    PageDown = @intCast(0x22),

    Unknown = @intCast(0),
};

pub fn keycodeFromInt(num: u32) KeyCode {
    return @enumFromInt(num);
}
