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
    red: f32,
    green: f32,
    blue: f32,

    pub fn create(ptr: *Square) !void {
        ptr.* = Square{
            .x = 0,
            .y = 0,
            .z = -5,
            .size = 1,
            .red = 0.0,
            .green = 0.0,
            .blue = 0.0
        };
    }

    pub fn render(self: *Square, _: void) !void {
        const s = self.size / 2.0;

        c.glPushMatrix();
        c.glTranslatef(self.x, self.y, self.z);

        c.glBegin(c.GL_QUADS);

        c.glColor3f(self.red, self.green, self.blue);
        c.glVertex3f(-s, -s, -s);
        c.glVertex3f(-s, s, -s);
        c.glVertex3f(s, s, -s);
        c.glVertex3f(s, -s, -s);

        c.glEnd();
        c.glPopMatrix();
    }
};
