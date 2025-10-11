const std = @import("std");

const App = @import("../app.zig").App;
const WindowEvents = @import("events/window_events.zig").WindowEvents;
const RenderEvents = @import("events/render_events.zig").RenderEvents;
const KeyCode = @import("../event-system/models/key_code.zig").KeyCode;
const WindowSize = @import("../event-system/models/window_size.zig").WindowSize;
const MousePosition = @import("../event-system/models/mouse_position.zig").MousePosition;

pub const EventManager = struct {
    arena_allocator: *std.heap.ArenaAllocator,

    app: *App,
    window_events: *WindowEvents,
    render_events: *RenderEvents,

    mutex: std.Thread.Mutex,
    thread: std.Thread,
    event_queue: std.ArrayList(RawEventThreaded),
    event_queue_condition: std.Thread.Condition,

    pub fn create(arena_allocator: *std.heap.ArenaAllocator, app: *App) !EventManager {
        // Allocate events
        const window_events_ptr = try arena_allocator.allocator().create(WindowEvents);
        window_events_ptr.* = try WindowEvents.init();

        const render_events_ptr = try arena_allocator.allocator().create(RenderEvents);
        render_events_ptr.* = try RenderEvents.init();

        return EventManager{
            .arena_allocator = arena_allocator,
            .app = app,
            .window_events = window_events_ptr,
            .render_events = render_events_ptr,
            .mutex = std.Thread.Mutex{},
            .thread = undefined,
            .event_queue = std.ArrayList(RawEventThreaded){},
            .event_queue_condition = std.Thread.Condition{},
        };
    }

    /// Starts event thread
    pub fn startThread(self: *EventManager) !void {
        self.thread = try std.Thread.spawn(.{}, eventThreadLoop, .{self});
    }

    /// Puts event in event queue to be dispatched on event thread
    ///
    /// # Arguments
    /// * `event`: Event to be dispatched
    pub fn dispatchEventOnEventThread(self: *EventManager, event: RawEventThreaded) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Add event to queue and signal to main thread that event is available
        self.event_queue.append(self.arena_allocator.allocator(), event) catch |e| {
            std.log.err("Failed to add event to queue: {}", .{e});
        };

        self.event_queue_condition.signal();
    }

    /// Dispatches event on main thread
    ///
    /// # Arguments
    /// * `event`: Event to be dispatched
    pub fn dispatchEventOnMainThread(self: *EventManager, event: RawEvent) void {
        self.mainThreadDispatch(event);
    }

    pub fn getWindowEvents(self: *EventManager) *WindowEvents {
        return self.window_events;
    }

    pub fn getRenderEvents(self: *EventManager) *RenderEvents {
        return self.render_events;
    }

    // --------------------------- HLPER FUNCTIONS --------------------------- //
    fn mainThreadDispatch(self: *EventManager, event: RawEvent) void {
        switch (event) {
            .Update => {
                self.render_events.on_update.dispatch(event.Update) catch |e| mainThreadEventDispatchFailed(e, event);
            },
            .Render => {
                self.render_events.on_render.dispatch(event.Render) catch |e| mainThreadEventDispatchFailed(e, event);
            },
            .PostRender => {
                self.render_events.on_post_render.dispatch(event.PostRender) catch |e| mainThreadEventDispatchFailed(e, event);
            },
        }
    }

    fn mainThreadEventDispatchFailed(e: anyerror, raw_event: RawEvent) void {
        std.log.err("Failed to dispatch event (MAIN THREAD): {}", .{e});
        std.log.err("Event: {any}", .{raw_event});
    }

    fn eventThreadLoop(self: *EventManager) void {
        while (true) {
            self.mutex.lock();
            defer self.mutex.unlock();

            // This is efficient way to wait for event to be available
            while (self.event_queue.items.len == 0) {
                self.event_queue_condition.wait(&self.mutex);
            }

            // Dispatch all queued events
            while (self.event_queue.items.len > 0) {

                // Get and remove event from queue and dispatch
                if (self.event_queue.pop()) |raw_event| {
                    switch (raw_event) {
                        .KeyDown => {
                            self.window_events.on_key_down.dispatch(raw_event.KeyDown) catch |e| threadedEventDispetchFailed(e, raw_event);
                        },
                        .KeyUp => {
                            self.window_events.on_key_up.dispatch(raw_event.KeyUp) catch |e| threadedEventDispetchFailed(e, raw_event);
                        },
                        .WindowClose => {
                            self.window_events.on_window_close.dispatch(raw_event.WindowClose) catch |e| threadedEventDispetchFailed(e, raw_event);
                        },
                        .WindowDestroy => {
                            self.window_events.on_window_destroy.dispatch(raw_event.WindowDestroy) catch |e| threadedEventDispetchFailed(e, raw_event);
                        },
                        .WindowResize => {
                            self.window_events.on_window_resize.dispatch(raw_event.WindowResize) catch |e| threadedEventDispetchFailed(e, raw_event);
                        },
                        .MouseMove => {
                            self.window_events.on_mouse_move.dispatch(raw_event.MouseMove) catch |e| threadedEventDispetchFailed(e, raw_event);
                        },
                        .WindowFocusGain => {
                            self.window_events.on_window_focus_gain.dispatch(raw_event.WindowFocusGain) catch |e| threadedEventDispetchFailed(e, raw_event);
                        },
                        .WindowFocusLose => {
                            self.window_events.on_window_focus_lose.dispatch(raw_event.WindowFocusLose) catch |e| threadedEventDispetchFailed(e, raw_event);
                        },
                        .Update => {
                            self.render_events.on_update.dispatch(raw_event.Update) catch |e| threadedEventDispetchFailed(e, raw_event);
                        },
                        .PostRender => {
                            self.render_events.on_post_render.dispatch(raw_event.PostRender) catch |e| threadedEventDispetchFailed(e, raw_event);
                        },
                    }
                }
            }
        }
    }

    fn threadedEventDispetchFailed(e: anyerror, raw_event: RawEventThreaded) void {
        std.log.err("Failed to dispatch event (EVENT THREAD): {}", .{e});
        std.log.err("Event: {any}", .{raw_event});
    }
};

pub const RawEventThreaded = union(enum) {
    KeyDown: KeyCode,
    KeyUp: KeyCode,
    WindowClose: void,
    WindowDestroy: void,
    WindowResize: WindowSize,
    MouseMove: MousePosition,
    WindowFocusGain: void,
    WindowFocusLose: void,
    Update: f64,
    PostRender: f64,
};

pub const RawEvent = union(enum) {
    Update: f64,
    Render: void,
    PostRender: f64,
};
