const std = @import("std");

const caster = @import("../utils/caster.zig");

const c_allocator_util = @import("../utils/c_allocator_util.zig");
const cRawAlloc = c_allocator_util.cRawAlloc;
const cRawFree = c_allocator_util.cRawFree;

const GameObject = @import("./game_object.zig").GameObject;

pub const ComponentWrapper = struct {
    component: *anyopaque, // Underlying component
    component_size: usize, // Used to free up raw allocated memory of underlying component
    component_alignment: std.mem.Alignment, // Used to free up raw allocated memory of underlying component
    game_object: *GameObject,

    fn_create: *const fn (*anyopaque) anyerror!void,
    fn_start: ?*const fn (*anyopaque) anyerror!void,
    fn_update: ?*const fn (f64, ?*anyopaque) anyerror!void,
    fn_render: ?*const fn (void, ?*anyopaque) anyerror!void,
    fn_post_render: ?*const fn (f64, ?*anyopaque) anyerror!void,
    fn_destroy: ?*const fn (*anyopaque) anyerror!void,

    /// Creates component wrapper
    ///
    /// # Arguments
    /// - `arena_allocator`: Arena allocator to use for component creation
    /// - `game_object`: Game object to which component belongs
    /// - `TComponent`: Component type
    ///
    /// # Returns
    /// - `ComponentWrapper`
    ///
    /// # Errors
    /// - `RawMemoryAllocationFailed`: Failed to allocate raw memory for underlying component
    /// - `UnderlyingComponentCreateFunctionFailed`: Failed to call create function of underlying component
    /// - `CastFromNullableAnyopaqueFailed`: Failed to cast from nullable anyopaque
    pub fn create(game_object: *GameObject, comptime TComponent: type) ComponentWrapperError!ComponentWrapper {
        // Ensure that unferlying component has create function and game_object field
        if (!@hasDecl(TComponent, "create")) {
            @compileError("ComponentWrapper " ++ @typeName(TComponent) ++ " must have a create function");
        }
        if (!@hasField(TComponent, "game_object")) {
            @compileError("ComponentWrapper " ++ @typeName(TComponent) ++ " must have a game_object field");
        }

        // Get function pointers
        const fn_create: *const fn (*anyopaque) anyerror!void = if (@hasDecl(TComponent, "create")) getCreateFnPtr(TComponent) else null;
        const fn_start: ?*const fn (*anyopaque) anyerror!void = if (@hasDecl(TComponent, "start")) getStartFnPtr(TComponent) else null;
        const fn_update: ?*const fn (f64, ?*anyopaque) anyerror!void = if (@hasDecl(TComponent, "update")) getUpdateFnPtr(TComponent) else null;
        const fn_render: ?*const fn (void, ?*anyopaque) anyerror!void = if (@hasDecl(TComponent, "render")) getRenderFnPtr(TComponent) else null;
        const fn_post_render: ?*const fn (f64, ?*anyopaque) anyerror!void = if (@hasDecl(TComponent, "postRender")) getPostRenderFnPtr(TComponent) else null;
        const fn_destroy: ?*const fn (*anyopaque) anyerror!void = if (@hasDecl(TComponent, "destroy")) getDestroyFnPtr(TComponent) else null;

        // ---------------------------------------------------------------------------------------------------------------------
        // Allocate raw memory for underlying component
        // Unfortunately, we need to do this because we can't save underlying component type in component wrapper
        const component_size = @sizeOf(TComponent);
        const component_alignment = std.mem.Alignment.of(TComponent);
        const unknown_component_mem: ?[*]u8 = cRawAlloc(component_size, component_alignment);

        // We cant allow further component creationg because raw memory allocationd failed
        if (unknown_component_mem == null) {
            return ComponentWrapperError.RawMemoryAllocationFailed;
        }

        // Call create function of underlying component which is suppoed to set instance of underlying component
        // Thats how we are able to get instance of underlying component
        const comp: *anyopaque = @ptrCast(unknown_component_mem);
        fn_create(comp) catch {
            freeRawAllocatedMemory(comp, component_size, component_alignment);
            return ComponentWrapperError.UnderlyingComponentCreateFunctionFailed;
        };
        // ---------------------------------------------------------------------------------------------------------------------

        // Sets game_object reference in underlying component
        const typed: *TComponent = caster.castFromNullableAnyopaque(TComponent, comp) catch {
            freeRawAllocatedMemory(comp, component_size, component_alignment);
            return ComponentWrapperError.CastFromNullableAnyopaqueFailed;
        };

        typed.game_object = game_object;

        return ComponentWrapper{
            .component = comp,
            .component_size = component_size,
            .component_alignment = component_alignment,
            .game_object = game_object,
            .fn_create = fn_create,
            .fn_start = fn_start,
            .fn_update = fn_update,
            .fn_render = fn_render,
            .fn_post_render = fn_post_render,
            .fn_destroy = fn_destroy,
        };
    }

    pub fn destroy(self: *ComponentWrapper) !void {
        try self.unbindRenderEvents();

        // Call destroy function
        if (self.fn_destroy) |fn_destroy| {
            try fn_destroy(self.component);
        }

        // Free underlying component memory
        freeRawAllocatedMemory(self.component, self.component_size, self.component_alignment);
    }

    /// NOTE: MUST BE CALLED
    /// NOTE: In case that start function fails component wrapper is destroyed
    pub fn start(self: *ComponentWrapper) !void {
        try self.bindRenderEvents();

        if (self.fn_start) |fn_start| {
            fn_start(self.component) catch {
                try self.destroy();
            };
        }
    }

    pub fn getComponent(self: *ComponentWrapper) *anyopaque {
        return self.component;
    }

    pub fn getComponentAsType(self: *ComponentWrapper, comptime TComponent: type) *TComponent {
        return @ptrCast(@alignCast(self.component));
    }

    // --------------------------- HELPER FUNCTIONS --------------------------- //
    /// Registeres render events (OnRender, OnUpdate, OnPostRender)
    fn bindRenderEvents(self: *ComponentWrapper) !void {
        if (self.fn_update) |fn_update| {
            try self.game_object.app.event_system.render_events.registerOnUpdate(fn_update, self.component);
        }

        if (self.fn_post_render) |fn_post_render| {
            try self.game_object.app.event_system.render_events.registerOnPostRender(fn_post_render, self.component);
        }
    }

    /// Unregisters render events (OnRender, OnUpdate, OnPostRender)
    fn unbindRenderEvents(self: *ComponentWrapper) !void {
        if (self.fn_update) |fn_update| {
            try self.game_object.app.event_system.render_events.unregisterOnUpdate(fn_update, self.component);
        }

        if (self.fn_post_render) |fn_post_render| {
            try self.game_object.app.event_system.render_events.unregisterOnPostRender(fn_post_render, self.component);
        }
    }

    /// Frees raw allocated memory used for underlying component
    fn freeRawAllocatedMemory(component: *anyopaque, component_size: usize, component_alignment: std.mem.Alignment) void {
        const mem: [*]u8 = @ptrCast(component);
        cRawFree(mem, component_size, component_alignment);
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

pub const ComponentWrapperError = error{
    RawMemoryAllocationFailed,
    CastFromNullableAnyopaqueFailed,
    UnderlyingComponentCreateFunctionFailed,
};
