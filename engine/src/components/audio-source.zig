const std = @import("std");
const typeId = @import("../utils/type-id.zig").typeId;

const App = @import("../app.zig").App;
const Transform = @import("../components/transform.zig").Transform;
const GameObject = @import("../game-object/game-object.zig").GameObject;
const SoundGroup = @import("../sound-system/sound-group.zig").SoundGroup;
const SoundOptions = @import("../sound-system/sound-source-sound-options.zig").SoundSourceSoundOptions;
const SoundSystem = @import("../sound-system/sound-system.zig").SoundSystem;
const Sound = @import("../sound-system/sound.zig").Sound;

pub fn AudioSource(parent_sound_group_name: ?[:0]const u8) type {
    return struct {
        const Self = @This();

        game_object: ?*GameObject = null,
        transform: *Transform = undefined,

        sound_system: *SoundSystem = undefined,
        sound_group: *SoundGroup = undefined,
        sounds: std.ArrayList(*Sound) = undefined,

        pub fn create(ptr: *Self) !void {
            ptr.* = Self{};
        }

        pub fn start(self: *Self) !void {
            const app = App.get();

            self.sound_system = app.sound_system;
            self.transform = self.game_object.?.getComponent(Transform) orelse return error.TransformNotFound;

            const group_id = try std.fmt.allocPrint(std.heap.c_allocator, "{}", .{self.game_object.?.unique_id});
            defer std.heap.c_allocator.free(group_id);
            self.sound_group = try self.sound_system.createGroup(.{
                .unique_name = group_id,
                .parent = if (parent_sound_group_name) |parent_name| try self.sound_system.getGroup(parent_name) else null,
            });

            self.sounds = try std.ArrayList(*Sound).initCapacity(std.heap.c_allocator, 4);
        }

        pub fn fixedUpdate(self: *Self, _: f32) !void {
            const postion_array = self.transform.position.toArray();

            for (self.sounds.items) |sound|
                sound.setPosition(postion_array);
        }

        pub fn playSound(self: *Self, options: SoundOptions) !*Sound {
            const new = try self.sound_system.playSoundGlobally(.{
                .file_path = options.file_path,
                .flags = options.flags,
                .sound_group = self.sound_group,
                .volume = options.base_volume,
            });

            new.setAttenuationModel(.linear);
            new.setRolloff(options.rolloff);
            new.setMinDistance(options.min_distance);
            new.setMaxDistance(options.max_distance);
            new.setCone(1, 1.57, 0.2); // 1 ~= 60deg, 1.57 ~= 90deg

            new.setPosition(self.transform.position.toArray());
            self.sounds.append(std.heap.c_allocator, new) catch unreachable;

            return new;
        }

        pub fn getId() u32 {
            return typeId(AudioSource(""));
        }
    };
}
