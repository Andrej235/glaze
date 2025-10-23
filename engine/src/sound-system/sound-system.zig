const zaudio = @import("zaudio");

const AudioListener = @import("../components/audio-listener.zig").AudioListener;

pub const SoundSystem = struct {
    listener: ?*AudioListener = null,

    pub fn create() !SoundSystem {
        return SoundSystem{};
    }

    pub fn makeListenerCurrent(self: *SoundSystem, listener: *AudioListener) !void {
        if (self.listener != null) {
            return error.ListenerAlreadySet;
        }

        self.listener = listener;
    }
};
