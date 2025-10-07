const std = @import("std");

pub const Platform = enum {
    linux,
    windows,
    macos,
    unknown,
};

pub const Renderer = enum {
    wayland,
    x11,
    win32,
    cocoa,
    null,
};

pub const current_platform: Platform = p: {
    if (@import("builtin").os.tag == .linux) break :p .linux;
    if (@import("builtin").os.tag == .windows) break :p .windows;
    if (@import("builtin").os.tag == .macos) break :p .macos;
    break :p .unknown;
};

pub fn detectRenderer() Renderer {
    return switch (current_platform) {
        .linux => r: {
            if (std.posix.getenv("WAYLAND_DISPLAY")) |_| break :r .wayland;
            if (std.posix.getenv("DISPLAY")) |_| break :r .x11;
            break :r .null;
        },
        .windows => .win32,
        .macos => .cocoa,
        else => .null,
    };
}
