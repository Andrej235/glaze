const std = @import("std");
const zaudio = @import("zaudio");

const Caster = @import("../utils/caster.zig");
const allocateNewArena = @import("../utils/arena-allocator-util.zig").allocateNewArena;

const App = @import("../app.zig").App;

const AudioListener = @import("../components/audio-listener.zig").AudioListener;
const Sound = @import("./sound.zig").Sound;
const SoundGroup = @import("./sound-group.zig").SoundGroup;
const SoundOptions = @import("./global-sound-options.zig").GlobalSoundOptions;
const SoundGroupOptions = @import("./sound-group-options.zig").SoundGroupOptions;

pub const SoundSystem = struct {
    allocator: std.mem.Allocator,

    listener: ?*AudioListener = null,
    engine: *zaudio.Engine = undefined,

    groups: std.StringHashMap(*SoundGroup) = undefined,
    sounds_cleanup_queue: std.ArrayList(*Sound) = undefined,

    pub fn create() !*SoundSystem {
        const app = App.get();

        const arena: *std.heap.ArenaAllocator = try allocateNewArena();
        const allocator = arena.allocator();

        zaudio.init(allocator);
        const audio_engine = try zaudio.Engine.create(null);

        const this = allocator.create(SoundSystem) catch unreachable;
        this.* = SoundSystem{
            .allocator = allocator,
            .engine = audio_engine,

            .groups = std.StringHashMap(*SoundGroup).init(allocator),
            .sounds_cleanup_queue = std.ArrayList(*Sound){},
        };

        _ = try app.event_system.render_events.registerOnFixedUpdate(fixedUpdate, this);

        return this;
    }

    pub fn makeListenerCurrent(self: *SoundSystem, listener: *AudioListener) !void {
        if (self.listener != null) {
            return error.ListenerAlreadySet;
        }

        self.listener = listener;
        self.engine.setListenerPosition(0, self.listener.?.transform.position.toArray());
        self.engine.setListenerDirection(0, .{ 0.0, 0.0, -1.0 });
        self.engine.setListenerWorldUp(0, .{ 0.0, 1.0, 0.0 });
    }

    pub fn fixedUpdate(_: f32, data: ?*anyopaque) !void {
        const self = try Caster.castFromNullableAnyopaque(SoundSystem, data);
        if (self.listener) |listener|
            self.engine.setListenerPosition(0, listener.transform.position.toArray());

        // automatic sound cleanup
        var len = self.sounds_cleanup_queue.items.len;
        var i: usize = 0;

        while (i < len) : (i += 1) {
            const sound = self.sounds_cleanup_queue.items[i];

            if (!sound.isPlaying()) {
                sound.destroy();
                _ = self.sounds_cleanup_queue.swapRemove(i);
                len -= 1;
            }
        }
    }

    pub fn createGroup(self: *SoundSystem, options: SoundGroupOptions) !*SoundGroup {
        const group = try self.groups.getOrPutValue(
            options.unique_name,
            try self.engine.createSoundGroup(
                options.flags,
                options.parent,
            ),
        );
        return group.value_ptr.*;
    }

    pub fn removeGroup(self: *SoundSystem, name: []const u8) !void {
        _ = self.groups.remove(name);
    }

    pub fn getGroup(self: *SoundSystem, name: []const u8) !*SoundGroup {
        return self.groups.get(name) orelse error.GroupNotFound;
    }

    pub fn playSoundGlobally(self: *SoundSystem, options: SoundOptions) !*Sound {
        const sound = try self.engine.createSoundFromFile(
            options.file_path,
            .{
                .flags = options.flags,
                .sgroup = options.sound_group,
            },
        );

        sound.setVolume(options.volume);
        try sound.start();

        // Cleanup refers to expired sounds, a looping sound can never expire
        if (!options.flags.looping)
            try self.sounds_cleanup_queue.append(self.allocator, sound);

        return sound;
    }
};
