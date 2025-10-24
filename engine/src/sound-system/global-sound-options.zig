const SoundFlags = @import("./sound-flags.zig").SoundFlags;
const SoundGroup = @import("./sound-group.zig").SoundGroup;

pub const GlobalSoundOptions = struct {
    file_path: [:0]const u8,
    flags: SoundFlags = .{},
    sound_group: ?*SoundGroup = null,
    volume: f32 = 1.0,
};
