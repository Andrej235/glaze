const std = @import("std");

const caster = @import("../utils/caster.zig");

const GameObject = @import("./game_object.zig").GameObject;

pub const Component = struct {
    arena_allocator: *std.heap.ArenaAllocator,

    component: ?*anyopaque, // Underlying component
    component_size: u32, // Used to free up raw allocated memory of underlying component
    component_alignment: ?std.mem.Alignment, // Used to free up raw allocated memory of underlying component
    game_object: *GameObject,

    fn_create: *const fn (*anyopaque) anyerror!void,
    fn_start: ?*const fn (*anyopaque) anyerror!void,
    fn_update: ?*const fn (f64, ?*anyopaque) anyerror!void,
    fn_render: ?*const fn (void, ?*anyopaque) anyerror!void,
    fn_post_render: ?*const fn (f64, ?*anyopaque) anyerror!void,
    fn_destroy: ?*const fn (*anyopaque) anyerror!void,

    pub fn create(
        arena_allocator: *std.heap.ArenaAllocator,
        game_object: *GameObject, 
        comptime TComponent: type
    ) !Component {
        // Enforce decl/field requirements
        if (!@hasDecl(TComponent, "create")) { @compileError("Component " ++ @typeName(TComponent) ++ " must have a create function"); }
        if (!@hasField(TComponent, "game_object")) { @compileError("Component " ++ @typeName(TComponent) ++ " must have a game_object field"); }

        // Get function pointers
        const fn_create: *const fn (*anyopaque) anyerror!void = if (@hasDecl(TComponent, "create")) getCreateFnPtr(TComponent) else null;
        const fn_start: ?*const fn (*anyopaque) anyerror!void = if (@hasDecl(TComponent, "start")) getStartFnPtr(TComponent) else null;
        const fn_update: ?*const fn (f64, ?*anyopaque) anyerror!void = if (@hasDecl(TComponent, "update")) getUpdateFnPtr(TComponent) else null;
        const fn_render: ?*const fn (void, ?*anyopaque) anyerror!void = if (@hasDecl(TComponent, "render")) getRenderFnPtr(TComponent) else null;
        const fn_post_render: ?*const fn (f64, ?*anyopaque) anyerror!void = if (@hasDecl(TComponent, "postRender")) getPostRenderFnPtr(TComponent) else null;
        const fn_destroy: ?*const fn (*anyopaque) anyerror!void = if (@hasDecl(TComponent, "destroy")) getDestroyFnPtr(TComponent) else null;

        var instance =  Component{
            .arena_allocator = arena_allocator,
            .component = null,
            .component_size = 0,
            .component_alignment = null,
            .game_object = game_object,
            .fn_create = fn_create,
            .fn_start = fn_start,
            .fn_update = fn_update,
            .fn_render = fn_render,
            .fn_post_render = fn_post_render,
            .fn_destroy = fn_destroy,
        };

        // Allocate memory for underlying component, and call create() ---------------------------------------------------------
        // We need to do this because we don't know type of underlying component and cant use .create() to allocate memory
        const component_size = @sizeOf(TComponent);
        const component_alignment = std.mem.Alignment.of(TComponent);
        const unknown_component_mem: ?[*]u8 = std.heap.page_allocator.rawAlloc(component_size, component_alignment, @returnAddress());

        // Save underlying component size and alignment to be able to free up raw allocated memory later
        instance.component_size = component_size;
        instance.component_alignment = component_alignment;

        // We cant allow further component creationg because raw memory allocationd failed
        if (unknown_component_mem == null) { return error.RawMemoryAllocationFailed; }
        else { instance.component = @ptrCast(unknown_component_mem); }

        // Invoke create function
        // If underlying component wasn't set it leads to undefined behavior
        try instance.fn_create(instance.component.?);
        // ---------------------------------------------------------------------------------------------------------------------

        // Set game object property of underlying component --------------------------------------------------------------------
        const typed: *TComponent = try caster.castFromNullableAnyopaque(TComponent, instance.component);
        typed.game_object = game_object;
        // ---------------------------------------------------------------------------------------------------------------------

        return instance;
    }

    /// Invokes create and start functions if they exist (MUST BE CALLED)
    pub fn start(self: *Component) !void {
        if (self.fn_start) |fn_start| {
            try fn_start(self.component.?);
        }
    }

    /// Invokes create and start functions if they exist (MUST BE CALLED)
    pub fn bindEvents(self: *Component) !void {
        try self.bindRenderEvents();
    }

    pub fn destroy(self: *Component) !void {
        try self.unbindRenderEvents();

        if (self.fn_destroy) |fn_destroy| { try fn_destroy(self.component.?); }

        // Free underlying component memory
        if (self.component) |component| {
            const mem: [*]u8 = @ptrCast(component);
            std.heap.page_allocator.rawFree(mem[0..self.component_size], self.component_alignment.?, @returnAddress());
            self.component = null;
        }

        self.fn_start = null;
        self.fn_update = null;
        self.fn_render = null;
        self.fn_post_render = null;
    }

    // --------------------------- HELPER FUNCTIONS --------------------------- //
    /// Registeres render events (OnRender, OnUpdate, OnPostRender)
    fn bindRenderEvents(self: *Component) !void {
        if (self.fn_render) |fn_render| {
            try self.game_object.app.event_system.render_events.registerOnRender(fn_render, self.component);
        }

        if (self.fn_update) |fn_update| {
            try self.game_object.app.event_system.render_events.registerOnUpdate(fn_update, self.component);
        }

        if (self.fn_post_render) |fn_post_render| {
            try self.game_object.app.event_system.render_events.registerOnPostRender(fn_post_render, self.component);
        }
    }

    /// Unregisters render events (OnRender, OnUpdate, OnPostRender)
    fn unbindRenderEvents(self: *Component) !void {
        if (self.fn_render) |fn_render| {
            try self.game_object.app.event_system.render_events.unregisterOnRender(fn_render, self.component);
        }

        if (self.fn_update) |fn_update| {
            try self.game_object.app.event_system.render_events.unregisterOnUpdate(fn_update, self.component);
        }

        if (self.fn_post_render) |fn_post_render| {
            try self.game_object.app.event_system.render_events.unregisterOnPostRender(fn_post_render, self.component);
        }
    }

    fn getCreateFnPtr(comptime TComponent: type) fn (*anyopaque) anyerror!void {
        return struct {
            fn call(ptr: *anyopaque) !void {
                const typed: *TComponent = try caster.castFromNullableAnyopaque(TComponent, ptr);
                try typed.create();
            }
        }.call;
    }

    fn getStartFnPtr(comptime TComponent: type) fn (*anyopaque) anyerror!void {
        return struct {
            fn call(ptr: *anyopaque) !void {
                const typed: *TComponent = try caster.castFromNullableAnyopaque(TComponent, ptr);
                try typed.start();
            }
        }.call;
    }

    fn getUpdateFnPtr(comptime TComponent: type) fn (f64, ?*anyopaque) anyerror!void {
        return struct {
            fn call(arg: f64, data: ?*anyopaque) anyerror!void {
                const typed: *TComponent = try caster.castFromNullableAnyopaque(TComponent, data);
                try typed.update(arg);
            }
        }.call;
    }

    fn getRenderFnPtr(comptime TComponent: type) fn (void, ?*anyopaque) anyerror!void {
        return struct {
            fn call(arg: void, data: ?*anyopaque) anyerror!void {
                const typed: *TComponent = try caster.castFromNullableAnyopaque(TComponent, data);
                try typed.render(arg);
            }
        }.call;
    }

    fn getPostRenderFnPtr(comptime TComponent: type) fn (f64, ?*anyopaque) anyerror!void {
        return struct {
            fn call(arg: f64, data: ?*anyopaque) anyerror!void {
                const typed: *TComponent = try caster.castFromNullableAnyopaque(TComponent, data);
                try typed.postRender(arg);
            }
        }.call;
    }

    fn getDestroyFnPtr(comptime TComponent: type) fn (*anyopaque) anyerror!void {
        return struct {
            fn call(ptr: *anyopaque) !void {
                const typed: *TComponent = try caster.castFromNullableAnyopaque(TComponent, ptr);
                try typed.destroy();
            }
        }.call;
    }
};