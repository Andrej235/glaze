const c = @cImport({
    @cInclude("windows.h");
    @cInclude("GL/gl.h");
});

pub const Cube = struct {
    x: f32,
    y: f32,
    z: f32,
    size: f32,

    pub fn create(x: f32, y: f32, z: f32, size: f32) Cube {
        return Cube{
            .x = x,
            .y = y,
            .z = z,
            .size = size,
        };
    }

    pub fn render(self: Cube) void {
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
