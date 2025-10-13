const KeyCode = @import("keycode.zig").KeyCode;
const detectRenderer = @import("../../utils/platform.zig").detectRenderer;

pub fn linuxKeyCodeMapper(code: u32) KeyCode {
    if (detectRenderer() == .wayland)
        return switch (code) {
            // Letters
            16 => .Q,
            17 => .W,
            18 => .E,
            19 => .R,
            20 => .T,
            21 => .Y,
            22 => .U,
            23 => .I,
            24 => .O,
            25 => .P,
            30 => .A,
            31 => .S,
            32 => .D,
            33 => .F,
            34 => .G,
            35 => .H,
            36 => .J,
            37 => .K,
            38 => .L,
            44 => .Z,
            45 => .X,
            46 => .C,
            47 => .V,
            48 => .B,
            49 => .N,
            50 => .M,

            // Numbers (top row)
            2 => .Num1,
            3 => .Num2,
            4 => .Num3,
            5 => .Num4,
            6 => .Num5,
            7 => .Num6,
            8 => .Num7,
            9 => .Num8,
            10 => .Num9,
            11 => .Num0,

            // Modifiers
            42 => .LeftShift,
            54 => .RightShift,
            29 => .LeftCtrl,
            97 => .RightCtrl,
            56 => .LeftAlt,
            100 => .RightAlt,
            125 => .LeftMeta,
            126 => .RightMeta, // Super / Windows keys

            // Arrows
            105 => .Left,
            106 => .Right,
            103 => .Up,
            108 => .Down,

            // Common keys
            1 => .Escape,
            14 => .Backspace,
            15 => .Tab,
            28 => .Enter,
            57 => .Space,
            111 => .Delete,
            110 => .Insert,
            102 => .Home,
            107 => .End,
            104 => .PageUp,
            109 => .PageDown,

            // Function keys
            59 => .F1,
            60 => .F2,
            61 => .F3,
            62 => .F4,
            63 => .F5,
            64 => .F6,
            65 => .F7,
            66 => .F8,
            67 => .F9,
            68 => .F10,
            87 => .F11,
            88 => .F12,

            // Symbols (common US layout)
            12 => .Minus,
            13 => .Equal,
            26 => .LeftBracket,
            27 => .RightBracket,
            39 => .Semicolon,
            40 => .Apostrophe,
            41 => .Grave,
            43 => .Backslash,
            51 => .Comma,
            52 => .Period,
            53 => .Slash,

            // Numpad
            82 => .Num0,
            79 => .Num1,
            80 => .Num2,
            81 => .Num3,
            75 => .Num4,
            76 => .Num5,
            77 => .Num6,
            71 => .Num7,
            72 => .Num8,
            73 => .Num9,
            83 => .NumDot,
            55 => .NumMultiply,
            78 => .NumMinus,
            74 => .NumPlus,
            96 => .NumEnter,
            98 => .NumDivide,

            else => .Unknown,
        };
        
    return .Unknown;
}
