const std = @import("std");

const setup = @import("setup.zig");

const App = @import("app.zig").App;

pub fn main() !void {
    // Create app instance
    const app: *App = try App.create();

    // Run setup
    try setup.setup(app);

    // Show main window
    try app.window.show();
    try app.window.run();
}
