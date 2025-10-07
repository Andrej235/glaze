const std = @import("std");
const c = @cImport({
    @cInclude("GL/gl.h");
});

const GameObject = @import("../game_object.zig").GameObject;

pub const Square = struct {
    game_object: ?*GameObject = null,

    x: f32,
    y: f32,
    z: f32,
    size: f32,

    pub fn create(ptr: *Square) !void {
        ptr.* = Square{
            .x = 0,
            .y = 0,
            .z = -5,
            .size = 1,
        };
    }

    pub fn render(self: *Square, _: void) !void {
        const s = self.size / 2.0;

        c.glPushMatrix();
        c.glTranslatef(self.x, self.y, self.z);

        // Draw cube (6 faces, wireframe for now)
        c.glBegin(c.GL_QUADS);

        // back
        c.glColor3f(0, 1, 0);
        c.glVertex3f(-s, -s, -s);
        c.glVertex3f(-s, s, -s);
        c.glVertex3f(s, s, -s);
        c.glVertex3f(s, -s, -s);

        c.glEnd();
        c.glPopMatrix();
    }
};
