const std = @import("std");

const caster = @import("utils/caster.zig");
const event_manager = @import("event-system/event_manager.zig");
const render_system = @import("render-system/render_system.zig");

const RenderSystem = render_system.RenderSystem;
const DynString = @import("utils/dyn_string.zig").DynString;
const Cube = @import("render-system/objects/cube.zig").Cube;
const KeyCode = @import("event-system/models/key_code.zig").KeyCode;

pub fn setup() !void {
    
    // Get systems
    const rs_ptr = try render_system.getRenderSystem();

    // Register player
    const player_ptr = try rs_ptr.allocate(Player);
    const player_script_ptr = try rs_ptr.allocate(PlayerScript);

    player_ptr.* = Player.init(try DynString.initConstText("Random Player"));
    player_script_ptr.* = PlayerScript.init(player_ptr);

    try rs_ptr.addEntity(Player, PlayerScript, player_ptr, player_script_ptr);
}

const Player = struct {
    cube: Cube,
    name: *DynString,

    pub fn init(name: *DynString) Player {
        return Player{
            .name = name,
            .cube = Cube.create(0.0, 0.0, -5, 0.5),
        };
    }

    pub fn render(self: *Player) !void {
        self.cube.render();
    }

    pub fn deinit(_: *Player) !void {
        std.debug.print("\nPlayer Deinit Invoked", .{});
    }
};

const PlayerScript = struct {
    entity: *Player,

    pub fn init(entity: *Player) PlayerScript {
        return PlayerScript{
            .entity = entity,
        };
    }

    // --------------------------- DEFAULT FUNCTIONS --------------------------- //
    pub fn start(self: *PlayerScript) !void {
        std.debug.print("\nPlayer Start Invoked", .{});

        // Register events
        const window_events = (try event_manager.getEventManager()).getWindowEvents();
        try window_events.registerOnKeyPressed(movePlayer, @ptrCast(@alignCast(self)));
    }

    pub fn update(_: *PlayerScript) !void { }

    pub fn deinit(_: *PlayerScript) !void { }

    // --------------------------- HELPER FUNCTIONS --------------------------- //
    fn movePlayer(key: KeyCode, data: ?*anyopaque) anyerror!void {
        const player_script = try caster.castFromNullableAnyopaque(PlayerScript, data);

        if (key == .A) {
            player_script.entity.cube.x -= 0.1;
        } else if (key == .D) {
            player_script.entity.cube.x += 0.1;
        } else if (key == .W) {
            player_script.entity.cube.y += 0.1;
        } else if (key == .S) {
            player_script.entity.cube.y -= 0.1;
        }

        std.debug.print("\nPlayer Move Invoked, Name is {s}, Key is {any}", .{player_script.entity.name.getText(), key});
    }
};
