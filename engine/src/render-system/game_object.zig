const std = @import("std");

const type_id = @import("../utils/type_id.zig");
const TypeId = type_id.TypeId;
const typeId = type_id.typeId;

const App = @import("../app.zig").App;
const Component = @import("./component.zig").Component;
const DynString = @import("../utils/dyn_string.zig").DynString;
const InputSystem = @import("../render-system/input-system/input.zig").InputSystem;

pub const GameObject = struct {
    arena_allocator: *std.heap.ArenaAllocator,

    mutex: std.Thread.Mutex,

    app: *App,
    input: *InputSystem,

    unique_id: usize,
    name: ?*DynString,
    tag: ?*DynString,

    // NOTE: The key in hashmap imitates component type
    components: std.AutoHashMap(u32, *Component),

    pub fn create(app: *App, arena: *std.heap.ArenaAllocator) !GameObject {
        return GameObject{
            .arena_allocator = arena,
            .mutex = std.Thread.Mutex{},
            .app = app,
            .input = app.input_system,
            .unique_id = 0,
            .name = null,
            .tag = null,
            .components = std.AutoHashMap(u32, *Component).init(arena.allocator()),
        };
    }

    pub fn destroy(self: *GameObject) !void {
        if (self.name) |name| { name.deinit(); }
        if (self.tag) |tag| { tag.deinit(); }

        var it = self.components.iterator();

        while (it.next()) |entry| {
            try entry.value_ptr.*.destroy();
        }

        self.components.deinit();
    }

    pub fn addComponent(self: *GameObject, comptime TComponent: type) void {
        const allocator = self.arena_allocator.allocator();

        self.mutex.lock();
        defer self.mutex.unlock();

        // Allocate memory for new component
        const n_component: *Component = allocator.create(Component) catch |e| {
            self.addComponentFailed(e, TComponent, null, false, false, false);
            return;
        };

        // Initialize new component
        n_component.* = Component.create(self.arena_allocator, self, TComponent) catch |e| {
            self.addComponentFailed(e, TComponent, n_component, true, false, false);
            return;
        };

        // Add component to game object
        self.components.put(typeId(TComponent), n_component) catch |e| {
            self.addComponentFailed(e, TComponent, n_component, true, true, false);
            return;
        };

        // Try to start and bind events for new component
        n_component.start() catch |e| {
            self.addComponentFailed(e, TComponent, n_component, true, true, true);
        };

        n_component.bindEvents() catch |e| {
            self.addComponentFailed(e, TComponent, n_component, true, true, true);
        };
    }

    pub fn removeComponentByType(self: *GameObject, comptime TComponent: type) void {
        const component_type_id: TypeId = typeId(TComponent);
        self.removeComponentByTypeId(component_type_id);
    }

    pub fn removeComponentByTypeId(self: *GameObject, component_type_id: TypeId) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Try to find component
        const component: ?*Component = self.components.get(component_type_id);
        if (component == null) { 
            std.log.err("Tried to remove component that does not exist", .{}); 
            return; 
        }

        // Remove component from game object
        const wasComponentFound = self.components.remove(component_type_id);
        if (!wasComponentFound) { 
            std.log.err("Tried to remove component that does not exist", .{});
            return; 
        }

        // Call destroy() on component to ensure all resources are freed
        component.?.destroy() catch |e| {
            std.log.err("Resources could not be freed: {}, remove component failed", .{e});
        };
    }

    /// NOTE: This only returns Component Wrapper not actual underlying component
    pub fn findComponentByType(self: *GameObject, comptime TComponent: type) ?*Component {
        const component_type_id: TypeId = typeId(TComponent);
        return self.findComponentByTypeId(component_type_id);
    }

    /// NOTE: This only returns Component Wrapper not actual underlying component
    pub fn findComponentByTypeId(self: *GameObject, component_type_id: TypeId) ?*Component {
        return self.components.get(component_type_id);
    }
    
    pub fn setId(self: *GameObject, id: usize) void {
        self.unique_id = id;
    }

    // --------------------------- HELPER FUNCTIONS --------------------------- //
    fn addComponentFailed(
        self: *GameObject, 
        err: anyerror,
        comptime TComponent: type,
        allocated_component: ?*Component,
        is_component_mem_allocated: bool,
        is_component_created: bool,
        is_component_saved: bool
    ) void {
        std.log.err("\nFailed to add new component: {}", .{err});

        if (is_component_created) {
            allocated_component.?.destroy() catch |e| {
                std.log.err("Failed to destroy newly allocated component: {}", .{e});
            };
        }

        if (is_component_mem_allocated) {
            self.arena_allocator.allocator().destroy(self);
        }

        if (is_component_saved) {
            const wasComponentFound = self.components.remove(typeId(TComponent));
            if (!wasComponentFound) { std.log.err("Failed to remove component from game object", .{}); }
        }
    }
};
