const std = @import("std");

const caster = @import("../utils/caster.zig");
const event_manager = @import("../event-system/event_manager.zig");

const RenderEvents = @import("../event-system/events/render_events.zig").RenderEvents;

pub const GameObject = struct {
    id: usize,

    render_events_ptr: *RenderEvents,

    entity_ptr: ?*anyopaque,
    entity_deinit_fptr: ?*const fn(*anyopaque) anyerror!void,
    entity_render_fptr: ?*const fn(*anyopaque) anyerror!void,

    script_ptr: ?*anyopaque,
    script_deinit_fptr: ?*const fn(*anyopaque) anyerror!void,
    script_update_fptr: ?*const fn(*anyopaque) anyerror!void,

    pub fn init() !GameObject {
        return GameObject{
            .id = 0,
            .render_events_ptr = (try event_manager.getEventManager()).getRenderEvents(),
            .entity_ptr = null,
            .entity_deinit_fptr = null,
            .entity_render_fptr = null,
            .script_ptr = null,
            .script_deinit_fptr = null,
            .script_update_fptr = null
        };
    }

    pub fn setEntity(self: *GameObject, comptime TEntity: type, entity: *TEntity) !void {
        if (!@hasDecl(TEntity, "render")) @compileError("TEntity must implement render()");
        if (!@hasDecl(TEntity, "deinit")) @compileError("TEntity must implement deinit()");

        self.entity_ptr = entity;

        // Save pointers to functions
        self.entity_render_fptr = struct {
            fn call(ptr: *anyopaque) !void {
                const typed: *TEntity = try caster.castFromNullableAnyopaque(TEntity, ptr);
                try typed.render();
            }
        }.call;

        self.entity_deinit_fptr = deinitWrapper(TEntity);

        // Connect events
        try self.render_events_ptr.registerOnRender(onRender, caster.castTPointerIntoAnyopaque(GameObject, self));
    }

    pub fn setScript(self: *GameObject, comptime TScript: type, script: *TScript) !void {
        if (!@hasDecl(TScript, "start")) @compileError("TScript must implement start()");
        if (!@hasDecl(TScript, "update")) @compileError("TScript must implement update()");
        if (!@hasDecl(TScript, "deinit")) @compileError("TScript must implement deinit()");

        self.script_ptr = script;
        
        // Save pointers to functions
        self.script_update_fptr = struct {
            fn call(ptr: *anyopaque) !void {
                const typed: *TScript = try caster.castFromNullableAnyopaque(TScript, ptr);
                try typed.update();
            }
        }.call;

        self.script_deinit_fptr = deinitWrapper(TScript);

        // Connect events
        try self.render_events_ptr.registerOnUpdate(onUpdate, caster.castTPointerIntoAnyopaque(GameObject, self));

        try script.start();
    }

    pub fn deinit(self: *GameObject) !void {
        std.debug.print("\nCalled deinit()\n", .{});

        // Call deinit functions
        if (self.script_ptr) |ptr| {
            if (self.script_deinit_fptr) |fn_ptr| {
                try fn_ptr(ptr);
            }
        }

        if (self.entity_ptr) |ptr| {
            if (self.entity_deinit_fptr) |fn_ptr| {
                try fn_ptr(ptr);
            }
        }

        // Reset pointers
        self.render_events_ptr = null;
        self.entity_ptr = null;
        self.script_ptr = null;
        self.entity_deinit_fptr = null;
        self.entity_render_fptr = null;
        self.script_deinit_fptr = null;
        self.script_update_fptr = null;
    }

    /// Sets the id of the game object. Its used to identify game objects.
    pub fn setId(self: *GameObject, id: usize) void {
        self.id = id;
    }

    // --------------------------- HELPER FUNCTIONS --------------------------- //
    fn deinitWrapper(comptime T: type) fn(*anyopaque) anyerror!void {
        return struct {
            fn call(ptr: *anyopaque) !void {
                const typed: *T = try caster.castFromNullableAnyopaque(T, ptr);
                try typed.deinit();
            }
        }.call;
    }

    /// Callback for render event
    fn onRender(_: void, data: ?*anyopaque) anyerror!void {
        const game_object = try caster.castFromNullableAnyopaque(GameObject, data);

        // Call game object render function
        if (game_object.entity_ptr) |ptr| {
            if (game_object.entity_render_fptr) |fn_ptr| {
                try fn_ptr(ptr);
            }
        }
    }

    /// Callback for update event
    fn onUpdate(_: void, data: ?*anyopaque) anyerror!void {
        const game_object = try caster.castFromNullableAnyopaque(GameObject, data);

        // Call game object update function
        if (game_object.script_ptr) |ptr| {
            if (game_object.script_update_fptr) |fn_ptr| {
                try fn_ptr(ptr);
            }
        }
    }
};
