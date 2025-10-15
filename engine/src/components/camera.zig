const GameObject = @import("../scene-manager/game_object.zig").GameObject;
const Transform = @import("transform.zig").Transform;

pub const Camera2D = struct {
    game_object: ?*GameObject = null,
    transform: ?*Transform = null,

    zoom: f32 = 1.0,

    pub fn create(ptr: *Camera2D) !void {
        ptr.* = Camera2D{};
    }

    pub fn makeViewMatrix(self: *Camera2D) [16]f32 {
        if (self.transform == null) {
            self.transform = self.game_object.?.getComponent(Transform);
        }

        var view: [16]f32 = [_]f32{
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1,
        };

        view[0] = self.zoom;
        view[5] = self.zoom;

        view[12] = -self.transform.?.position.x;
        view[13] = -self.transform.?.position.y;

        return view;
    }
};
