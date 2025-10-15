const std = @import("std");

const caster = @import("../utils/caster.zig");

const types = @import("../utils/types.zig");
const DeltaTime = types.Deltatime;

const c_allocator_util = @import("../utils/c_allocator_util.zig");
const cRawAlloc = c_allocator_util.cRawAlloc;
const cRawFree = c_allocator_util.cRawFree;

const App = @import("../app.zig").App;
const GameObject = @import("./game_object.zig").GameObject;
const EntryKey = @import("../event-system/event_dispatcher.zig").EntryKey;
const RenderEvents = @import("../event-system/events/render_events.zig").RenderEvents;

const FnCreate = *const fn (*anyopaque) anyerror!void;
const FnStart = *const fn (*anyopaque) anyerror!void;
const FnUpdate = *const fn (DeltaTime, ?*anyopaque) anyerror!void;
const FnRender = *const fn (void, ?*anyopaque) anyerror!void;
const FnPostRender = *const fn (DeltaTime, ?*anyopaque) anyerror!void;
const FnDestroy = *const fn (*anyopaque) anyerror!void;

pub const ComponentWrapper = struct {
    const Self = @This();

    component: *anyopaque, // Underlying component
    component_size: usize, // Used to free up raw allocated memory of underlying component
    component_alignment: std.mem.Alignment, // Used to free up raw allocated memory of underlying component

    render_events: *RenderEvents,
    game_object: *GameObject,

    events_id: [2]EntryKey = .{-1} ** 2, // NOTE: Change array size when more events are expected to be added

    is_active: bool,

    fn_create: FnCreate,
    fn_start: ?FnStart,
    fn_update: ?FnUpdate,
    fn_render: ?FnRender,
    fn_post_render: ?FnPostRender,
    fn_destroy: ?FnDestroy,

    /// Creates component wrapper
    ///
    /// # Arguments
    /// - `game_object`: Game object to which component belongs
    /// - `TComponent`: Component type
    ///
    /// # Returns
    /// - `ComponentWrapper`: Created component wrapper
    ///
    /// # Errors
    /// - `RawMemoryAllocationFailed`: Failed to allocate raw memory for underlying component
    /// - `UnderlyingComponentCreateFunctionFailed`: Failed to call create function of underlying component
    /// - `CastFromNullableAnyopaqueFailed`: Failed to cast from nullable anyopaque
    pub fn create(game_object: *GameObject, comptime TComponent: type) ComponentWrapperError!Self {
        // Get function pointers
        const fn_create = if (@hasDecl(TComponent, "create")) getCreateFnPtr(TComponent) else null;
        const fn_start = if (@hasDecl(TComponent, "start")) getStartFnPtr(TComponent) else null;
        const fn_update = if (@hasDecl(TComponent, "update")) getUpdateFnPtr(TComponent) else null;
        const fn_render = if (@hasDecl(TComponent, "render")) getRenderFnPtr(TComponent) else null;
        const fn_post_render = if (@hasDecl(TComponent, "postRender")) getPostRenderFnPtr(TComponent) else null;
        const fn_destroy = if (@hasDecl(TComponent, "destroy")) getDestroyFnPtr(TComponent) else null;

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

        return Self{
            .component = comp,
            .component_size = component_size,
            .component_alignment = component_alignment,
            .render_events = App.get().event_system.render_events,
            .game_object = game_object,
            .is_active = true,
            .fn_create = fn_create,
            .fn_start = fn_start,
            .fn_update = fn_update,
            .fn_render = fn_render,
            .fn_post_render = fn_post_render,
            .fn_destroy = fn_destroy,
        };
    }

    pub fn destroy(self: *Self) !void {
        try self.unbindRenderEvents();

        if (self.fn_destroy) |fn_destroy| try fn_destroy(self.component);

        freeRawAllocatedMemory(self.component, self.component_size, self.component_alignment);
    }

    pub fn start(self: *Self) !void {
        try self.bindRenderEvents();

        if (self.fn_start) |fn_start| try fn_start(self.component);
    }

    pub fn setActive(self: *Self, is_active: bool) !void {
        if (self.is_active == is_active) return;

        self.is_active = is_active;

        if (is_active) {
            try self.unpauseRenderEvents();
        } else {
            try self.pauseRenderEvents();
        }
    }

    ///#region Get functions
    pub fn getComponentAsType(self: *Self, comptime TComponent: type) *TComponent {
        return @ptrCast(@alignCast(self.component));
    }
    //#endregion

    // --------------------------- HELPER FUNCTIONS --------------------------- //
    /// Frees raw allocated memory used for underlying component
    fn freeRawAllocatedMemory(component: *anyopaque, component_size: usize, component_alignment: std.mem.Alignment) void {
        const mem: [*]u8 = @ptrCast(component);
        cRawFree(mem, component_size, component_alignment);
    }

    //#region Event binding
    fn bindRenderEvents(self: *Self) !void {
        if (self.fn_update) |fn_update|
            self.events_id[0] = try self.render_events.registerOnUpdate(fn_update, self.component);

        if (self.fn_post_render) |fn_post_render|
            self.events_id[1] = try self.render_events.registerOnPostRender(fn_post_render, self.component);
    }

    fn unbindRenderEvents(self: *Self) !void {
        if (self.fn_update) |_| try self.render_events.on_update.removeHandlerById(self.events_id[0]);
        if (self.fn_post_render) |_| try self.render_events.on_post_render.removeHandlerById(self.events_id[1]);

        self.events_id = .{-1} ** 2;
    }

    fn pauseRenderEvents(self: *Self) !void {
        if (self.fn_update) |_| try self.render_events.on_update.pauseHandlerById(self.events_id[0]);
        if (self.fn_post_render) |_| try self.render_events.on_post_render.pauseHandlerById(self.events_id[1]);
    }

    fn unpauseRenderEvents(self: *Self) !void {
        if (self.fn_update) |_| try self.render_events.on_update.resumeHandlerById(self.events_id[0]);
        if (self.fn_post_render) |_| try self.render_events.on_post_render.resumeHandlerById(self.events_id[1]);
    }
    //#endregion

    //#region Function Pointers
    fn getCreateFnPtr(comptime TComponent: type) FnCreate {
        return struct {
            fn call(ptr: *anyopaque) !void {
                const typed: *TComponent = try caster.castFromNullableAnyopaque(TComponent, ptr);
                try typed.create();
            }
        }.call;
    }

    fn getStartFnPtr(comptime TComponent: type) FnStart {
        return struct {
            fn call(ptr: *anyopaque) !void {
                const typed: *TComponent = try caster.castFromNullableAnyopaque(TComponent, ptr);
                try typed.start();
            }
        }.call;
    }

    fn getUpdateFnPtr(comptime TComponent: type) FnUpdate {
        return struct {
            fn call(arg: DeltaTime, data: ?*anyopaque) anyerror!void {
                const typed: *TComponent = try caster.castFromNullableAnyopaque(TComponent, data);
                try typed.update(arg);
            }
        }.call;
    }

    fn getRenderFnPtr(comptime TComponent: type) FnRender {
        return struct {
            fn call(arg: void, data: ?*anyopaque) anyerror!void {
                const typed: *TComponent = try caster.castFromNullableAnyopaque(TComponent, data);
                try typed.render(arg);
            }
        }.call;
    }

    fn getPostRenderFnPtr(comptime TComponent: type) FnPostRender {
        return struct {
            fn call(arg: DeltaTime, data: ?*anyopaque) anyerror!void {
                const typed: *TComponent = try caster.castFromNullableAnyopaque(TComponent, data);
                try typed.postRender(arg);
            }
        }.call;
    }

    fn getDestroyFnPtr(comptime TComponent: type) FnDestroy {
        return struct {
            fn call(ptr: *anyopaque) !void {
                const typed: *TComponent = try caster.castFromNullableAnyopaque(TComponent, ptr);
                try typed.destroy();
            }
        }.call;
    }
    //#endregion
};

pub const ComponentWrapperError = error{
    RawMemoryAllocationFailed,
    CastFromNullableAnyopaqueFailed,
    UnderlyingComponentCreateFunctionFailed,
};
