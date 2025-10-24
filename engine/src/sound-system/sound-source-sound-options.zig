const SoundFlags = @import("./sound-flags.zig").SoundFlags;
const SoundGroup = @import("./sound-group.zig").SoundGroup;

pub const SoundSourceSoundOptions = struct {
    file_path: [:0]const u8,
    flags: SoundFlags = .{},
    volume: f32 = 1.0,

    base_volume: f32 = 0.5,
    min_distance: f32 = 10.0,
    max_distance: f32 = 50.0,
    rolloff: f32 = 1.0,
};
