const App = @import("../app.zig").App;
const GameObject = @import("../game-object/game-object.zig").GameObject;

const Transform = @import("../components/transform.zig").Transform;
const SoundSystem = @import("../sound-system/sound-system.zig").SoundSystem;

pub const AudioListener = struct {
    game_object: ?*GameObject = null,
    transform: *Transform = undefined,

    sound_system: *SoundSystem = undefined,

    pub fn create(ptr: *AudioListener) !void {
        ptr.* = AudioListener{};
    }

    pub fn start(self: *AudioListener) !void {
        const app = App.get();

        self.sound_system = app.sound_system orelse return error.SoundSystemNotInitialized;
        self.transform = self.game_object.?.getComponent(Transform) orelse return error.TransformNotFound;
    }
};
