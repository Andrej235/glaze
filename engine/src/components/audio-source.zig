const App = @import("../app.zig").App;
const GameObject = @import("../game-object/game-object.zig").GameObject;

const Transform = @import("../components/transform.zig").Transform;
const SoundSystem = @import("../sound-system/sound-system.zig").SoundSystem;

pub const AudioSource = struct {
    game_object: ?*GameObject = null,
    transform: *Transform = undefined,

    sound_system: *SoundSystem = undefined,

    pub fn create(ptr: *AudioSource) !void {
        ptr.* = AudioSource{};
    }

    pub fn start(self: *AudioSource) !void {
        const app = App.get();

        self.sound_system = app.sound_system orelse return error.SoundSystemNotInitialized;
        self.transform = self.game_object.?.getComponent(Transform) orelse return error.TransformNotFound;
    }
};
