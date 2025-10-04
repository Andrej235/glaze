const WindowState = @import("window_state.zig").WindowState;

pub const WindowSize = struct {
    width: u32,
    height: u32,
    window_state: WindowState,

    pub fn init(width: u32, height: u32, window_state: WindowState) WindowSize {
        return WindowSize{ .width = width, .height = height, .window_state = window_state };
    }
};
