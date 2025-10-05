const std = @import("std");

const setup = @import("setup.zig");
const event_manager = @import("event-system/event_manager.zig");
const render_system = @import("render-system/render_system.zig");

const Window = @import("ui/window.zig").Window;

pub fn main() !void {

    // Initialize Window
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const w_instance = try arena.allocator().create(Window);
    w_instance.* = try Window.init(&arena);

    // Initialize Event System
    _ = try event_manager.getEventManager();

    // Initialize Render System
    _ = try render_system.getRenderSystem();

    // Run initial setup
    try setup.setup();

    // Show and Run main loop
    try w_instance.initPlatformWindow("GG", 800, 800);
    try w_instance.show();
    try w_instance.run();
}
