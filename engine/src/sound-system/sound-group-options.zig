const SoundGroup = @import("./sound-group.zig").SoundGroup;
const SoundFlags = @import("./sound-flags.zig").SoundFlags;

pub const SoundGroupOptions = struct {
    unique_name: []const u8,
    flags: SoundFlags = .{},
    parent: ?*SoundGroup = null,
};
