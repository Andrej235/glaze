#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>

#include <wayland-client.h>
#include <wayland-egl.h>
#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <xkbcommon/xkbcommon.h>
#include "xdg-shell-client-protocol.h"

struct wl_display *display = NULL;
struct wl_registry *registry = NULL;
struct wl_compositor *compositor = NULL;
struct xdg_wm_base *wm_base = NULL;

struct wl_surface *wl_surface = NULL;
struct xdg_surface *xdg_surface = NULL;
struct xdg_toplevel *xdg_toplevel = NULL;

struct wl_egl_window *egl_window = NULL;

struct wl_seat *seat = NULL;
struct wl_pointer *pointer = NULL;
struct wl_keyboard *keyboard = NULL;

struct xkb_context *xkb_ctx;
struct xkb_keymap *xkb_keymap;
struct xkb_state *xkb_state;

EGLDisplay egl_display = EGL_NO_DISPLAY;
EGLContext egl_context = EGL_NO_CONTEXT;
EGLSurface egl_surface = EGL_NO_SURFACE;
EGLConfig egl_config;

int win_width = 400;
int win_height = 400;

static struct wl_callback *frame_callback = NULL;
static GLuint program;
static float angle = 0.0f;

static void die(const char *msg)
{
    perror(msg);
    exit(EXIT_FAILURE);
}

static void xdg_wm_base_ping(void *data, struct xdg_wm_base *shell, uint32_t serial)
{
    (void)data;
    xdg_wm_base_pong(shell, serial);
}

static const struct xdg_wm_base_listener wm_base_listener = {.ping = xdg_wm_base_ping};

static void xdg_toplevel_configure(void *data, struct xdg_toplevel *toplevel,
                                   int32_t width, int32_t height, struct wl_array *states)
{
    (void)data;
    (void)toplevel;
    (void)states;

    if (width <= 0 || height <= 0)
        return;

    win_width = width;
    win_height = height;

    if (egl_window)
        wl_egl_window_resize(egl_window, win_width, win_height, 0, 0);
}

static void xdg_toplevel_close(void *data, struct xdg_toplevel *toplevel)
{
    (void)data;
    (void)toplevel;
    fprintf(stderr, "xdg_toplevel_close: exiting\n");
    exit(0);
}

static const struct xdg_toplevel_listener xdg_toplevel_listener = {
    .configure = xdg_toplevel_configure,
    .close = xdg_toplevel_close,
};

static void pointer_enter(void *data, struct wl_pointer *pointer,
                          uint32_t serial, struct wl_surface *surface,
                          wl_fixed_t sx, wl_fixed_t sy)
{
    printf("Pointer entered surface at %f,%f\n",
           wl_fixed_to_double(sx), wl_fixed_to_double(sy));
}

static void pointer_leave(void *data, struct wl_pointer *pointer,
                          uint32_t serial, struct wl_surface *surface)
{
    printf("Pointer left surface\n");
}

static void pointer_motion(void *data, struct wl_pointer *pointer,
                           uint32_t time, wl_fixed_t sx, wl_fixed_t sy)
{
    printf("Pointer moved to %f,%f\n",
           wl_fixed_to_double(sx), wl_fixed_to_double(sy));
}

static void pointer_button(void *data, struct wl_pointer *pointer,
                           uint32_t serial, uint32_t time,
                           uint32_t button, uint32_t state)
{
    printf("Pointer button %u %s\n", button,
           state == WL_POINTER_BUTTON_STATE_PRESSED ? "pressed" : "released");
}

static void pointer_axis(void *data, struct wl_pointer *pointer,
                         uint32_t time, uint32_t axis, wl_fixed_t value)
{
    printf("Pointer scrolled: %f\n", wl_fixed_to_double(value));
}

static void keyboard_enter(void *data, struct wl_keyboard *keyboard,
                           uint32_t serial, struct wl_surface *surface,
                           struct wl_array *keys)
{
    (void)keys;
    printf("Keyboard focus on surface\n");
}

static void keyboard_leave(void *data, struct wl_keyboard *keyboard,
                           uint32_t serial, struct wl_surface *surface)
{
    printf("Keyboard focus left surface\n");
}

static void keyboard_key(void *data, struct wl_keyboard *keyboard,
                         uint32_t serial, uint32_t time,
                         uint32_t key, uint32_t state)
{
    int pressed = state == WL_KEYBOARD_KEY_STATE_PRESSED;

    xkb_state_update_key(xkb_state, key + 8, pressed ? XKB_KEY_DOWN : XKB_KEY_UP);

    char buf[32];
    int n = xkb_state_key_get_utf8(xkb_state, key + 8, buf, sizeof(buf));
    if (n > 0)
    {
        buf[n] = '\0';
        printf("Key %s: %s\n", pressed ? "pressed" : "released", buf);
    }
}

static void keyboard_modifiers(void *data, struct wl_keyboard *keyboard,
                               uint32_t serial, uint32_t mods_depressed,
                               uint32_t mods_latched, uint32_t mods_locked,
                               uint32_t group)
{
    (void)mods_depressed;
    (void)mods_latched;
    (void)mods_locked;
    (void)group;
}

static void keyboard_keymap(void *data, struct wl_keyboard *keyboard,
                            uint32_t format, int fd, uint32_t size)
{
    if (format != WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1)
    {
        close(fd);
        return;
    }

    char *map_str = mmap(NULL, size, PROT_READ, MAP_SHARED, fd, 0);
    if (map_str == MAP_FAILED)
    {
        perror("mmap");
        close(fd);
        return;
    }

    xkb_ctx = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    if (!xkb_ctx)
        die("Failed to create xkb context");

    xkb_keymap = xkb_keymap_new_from_string(xkb_ctx, map_str, XKB_KEYMAP_FORMAT_TEXT_V1, 0);
    if (!xkb_keymap)
        die("Failed to create keymap");

    xkb_state = xkb_state_new(xkb_keymap);
    if (!xkb_state)
        die("Failed to create state");

    close(fd);
}

static void seat_capabilities(void *data, struct wl_seat *seat, uint32_t caps)
{
    if (caps & WL_SEAT_CAPABILITY_POINTER && !pointer)
    {
        pointer = wl_seat_get_pointer(seat);
        static const struct wl_pointer_listener pointer_listener = {
            .enter = pointer_enter,
            .leave = pointer_leave,
            .motion = pointer_motion,
            .button = pointer_button,
            .axis = pointer_axis,
        };
        wl_pointer_add_listener(pointer, &pointer_listener, NULL);
    }

    if (caps & WL_SEAT_CAPABILITY_KEYBOARD && !keyboard)
    {
        keyboard = wl_seat_get_keyboard(seat);
        static const struct wl_keyboard_listener keyboard_listener = {
            .keymap = keyboard_keymap,
            .enter = keyboard_enter,
            .leave = keyboard_leave,
            .key = keyboard_key,
            .modifiers = keyboard_modifiers,
        };
        wl_keyboard_add_listener(keyboard, &keyboard_listener, NULL);
    }
}

static const struct wl_seat_listener seat_listener = {
    .capabilities = seat_capabilities,
    .name = NULL // optional
};

static void registry_global(void *data, struct wl_registry *registry,
                            uint32_t id, const char *interface, uint32_t version)
{
    (void)data;
    (void)version;
    if (strcmp(interface, "wl_compositor") == 0)
    {
        compositor = wl_registry_bind(registry, id, &wl_compositor_interface, 1);
    }
    else if (strcmp(interface, "xdg_wm_base") == 0)
    {
        wm_base = wl_registry_bind(registry, id, &xdg_wm_base_interface, 1);
        xdg_wm_base_add_listener(wm_base, &wm_base_listener, NULL);
    }
    else if (strcmp(interface, "wl_seat") == 0)
    {
        seat = wl_registry_bind(registry, id, &wl_seat_interface, 1);
        wl_seat_add_listener(seat, &seat_listener, NULL);
    }
}

static void registry_global_remove(void *data, struct wl_registry *registry, uint32_t id)
{
    (void)data;
    (void)registry;
    (void)id;
}

static const struct wl_registry_listener registry_listener = {
    .global = registry_global,
    .global_remove = registry_global_remove,
};

static void egl_init()
{
    egl_display = eglGetDisplay((EGLNativeDisplayType)display);
    if (egl_display == EGL_NO_DISPLAY)
        die("eglGetDisplay");

    if (!eglInitialize(egl_display, NULL, NULL))
        die("eglInitialize");

    EGLint attribs[] = {
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
        EGL_RED_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE, 8,
        EGL_ALPHA_SIZE, 8,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
        EGL_NONE};

    EGLint num_configs;
    if (!eglChooseConfig(egl_display, attribs, &egl_config, 1, &num_configs) || num_configs < 1)
        die("eglChooseConfig");

    EGLint ctx_attribs[] = {EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE};
    egl_context = eglCreateContext(egl_display, egl_config, EGL_NO_CONTEXT, ctx_attribs);
    if (egl_context == EGL_NO_CONTEXT)
        die("eglCreateContext");
}

static GLuint compile_shader(GLenum type, const char *src)
{
    GLuint sh = glCreateShader(type);
    glShaderSource(sh, 1, &src, NULL);
    glCompileShader(sh);
    GLint ok = 0;
    glGetShaderiv(sh, GL_COMPILE_STATUS, &ok);
    if (!ok)
    {
        char buf[512];
        glGetShaderInfoLog(sh, sizeof(buf), NULL, buf);
        fprintf(stderr, "Shader compile error: %s\n", buf);
        die("shader compile");
    }
    return sh;
}

static GLuint make_program()
{
    const char *vsrc =
        "attribute vec2 position;\n"
        "uniform float angle;\n"
        "void main() {\n"
        "  float c = cos(angle);\n"
        "  float s = sin(angle);\n"
        "  gl_Position = vec4(c*position.x - s*position.y, s*position.x + c*position.y, 0.0, 1.0);\n"
        "}\n";
    const char *fsrc =
        "precision mediump float;\n"
        "void main() {\n"
        "  gl_FragColor = vec4(0.2, 0.6, 0.9, 1.0);\n"
        "}\n";

    GLuint vs = compile_shader(GL_VERTEX_SHADER, vsrc);
    GLuint fs = compile_shader(GL_FRAGMENT_SHADER, fsrc);

    GLuint prog = glCreateProgram();
    glAttachShader(prog, vs);
    glAttachShader(prog, fs);
    glBindAttribLocation(prog, 0, "position");
    glLinkProgram(prog);

    GLint ok = 0;
    glGetProgramiv(prog, GL_LINK_STATUS, &ok);
    if (!ok)
    {
        char buf[512];
        glGetProgramInfoLog(prog, sizeof(buf), NULL, buf);
        fprintf(stderr, "Program link error: %s\n", buf);
        die("program link");
    }

    glDeleteShader(vs);
    glDeleteShader(fs);

    return prog;
}

/* Draw rotating square */
static void draw_square(GLuint program)
{
    GLfloat verts[] = {
        -0.5f, -0.5f, 0.5f, -0.5f, 0.5f, 0.5f,
        -0.5f, -0.5f, 0.5f, 0.5f, -0.5f, 0.5f};

    glViewport(0, 0, win_width, win_height);
    glClearColor(0.1f, 0.1f, 0.1f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    glUseProgram(program);
    glUniform1f(glGetUniformLocation(program, "angle"), angle);

    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, verts);
    glDrawArrays(GL_TRIANGLES, 0, 6);
    glDisableVertexAttribArray(0);
}

/* ----- Frame callback ----- */
static void frame_done(void *data, struct wl_callback *cb, uint32_t time)
{
    (void)time;
    if (cb)
        wl_callback_destroy(cb);

    angle += 0.02f;

    draw_square(program);
    eglSwapBuffers(egl_display, egl_surface);

    // Schedule next frame callback for main surface
    frame_callback = wl_surface_frame(wl_surface);
    static const struct wl_callback_listener frame_listener = {.done = frame_done};
    wl_callback_add_listener(frame_callback, &frame_listener, NULL);
    wl_surface_commit(wl_surface);
}

static void xdg_surface_configure(void *data, struct xdg_surface *surface, uint32_t serial)
{
    xdg_surface_ack_configure(surface, serial);

    if (!frame_callback)
        frame_done(data, NULL, 0);
}

static const struct xdg_surface_listener xdg_surface_listener = {
    .configure = xdg_surface_configure};

int main()
{
    display = wl_display_connect(NULL);
    if (!display)
        die("wl_display_connect");

    registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    wl_display_roundtrip(display);

    if (!compositor || !wm_base)
    {
        fprintf(stderr, "Compositor missing wl_compositor or xdg_wm_base\n");
        return 1;
    }

    // main surface
    wl_surface = wl_compositor_create_surface(compositor);
    xdg_surface = xdg_wm_base_get_xdg_surface(wm_base, wl_surface);
    xdg_surface_add_listener(xdg_surface, &xdg_surface_listener, NULL);

    xdg_toplevel = xdg_surface_get_toplevel(xdg_surface);
    xdg_toplevel_add_listener(xdg_toplevel, &xdg_toplevel_listener, NULL);
    xdg_toplevel_set_title(xdg_toplevel, "Rotating Square");

    // egl setup
    egl_init();
    egl_window = wl_egl_window_create(wl_surface, win_width, win_height);
    egl_surface = eglCreateWindowSurface(egl_display, egl_config, (EGLNativeWindowType)egl_window, NULL);
    eglMakeCurrent(egl_display, egl_surface, egl_surface, egl_context);

    program = make_program();

    // commit main surface so configure fires
    wl_surface_commit(wl_surface);

    while (1)
    {
        wl_display_dispatch_pending(display);
        wl_display_flush(display);

        if (wl_display_prepare_read(display) == 0)
        {
            wl_display_flush(display);
            wl_display_read_events(display);
        }
        else
        {
            wl_display_dispatch_pending(display);
        }
    }

    return 0;
}
