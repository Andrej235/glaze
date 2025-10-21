pub const MousePosition = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) MousePosition {
        return MousePosition{ .x = x, .y = y };
    }
};
