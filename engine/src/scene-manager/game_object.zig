const std = @import("std");

const general_util = @import("../utils/general_util.zig");
const TypeId = general_util.TypeId;
const typeId = general_util.typeId;

const c_allocator_util = @import("../utils/c_allocator_util.zig");
const cAlloc = c_allocator_util.cAlloc;
const cFree = c_allocator_util.cFree;

const App = @import("../app.zig").App;
const ComponentWrapper = @import("./component_wrapper.zig").ComponentWrapper;
const DynString = @import("../utils/dyn_string.zig").DynString;
const InputSystem = @import("../scene-manager/input-system/input.zig").InputSystem;

pub const GameObject = struct {
    mutex: std.Thread.Mutex,

    app: *App,
    input: *InputSystem,

    unique_id: usize,
    name: ?*DynString,
    tag: ?*DynString,

    // NOTE: The key in hashmap imitates component type
    components: std.AutoHashMap(u32, *ComponentWrapper),

    pub fn create(app: *App) GameObject {
        return GameObject{
            .mutex = std.Thread.Mutex{},
            .app = app,
            .input = app.input_system,
            .unique_id = 0,
            .name = null,
            .tag = null,
            .components = std.AutoHashMap(u32, *ComponentWrapper).init(std.heap.c_allocator),
        };
    }

    pub fn destroy(self: *GameObject) !void {
        if (self.name) |name| {
            name.deinit();
        }
        if (self.tag) |tag| {
            tag.deinit();
        }

        // NOTE: Optimize this
        var it = self.components.iterator();
        while (it.next()) |entry| {
            try entry.value_ptr.*.destroy();
            cFree(entry.value_ptr.*);
        }
        self.components.deinit();
    }

    /// Adds component to game object
    ///
    /// # Arguments
    /// - `TComponent`: Component type
    ///
    /// # Returns
    /// - `ComponentWrapper`: Component wrapper
    ///
    /// # Errors
    /// - `ComponentWrapperAllocationFailed`: Failed to allocate memory for component
    /// - `ComponentWrapperCreationFailed`: Failed to create component wrapper
    /// - `ComponentWrapperAppendFailed`: Failed to append component to game object
    /// - `ComponentWrapperStartFailed`: Failed to start component
    pub fn addComponent(self: *GameObject, comptime TComponent: type) GameObjectError!*ComponentWrapper {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Allocate memory for new component
        const n_component: *ComponentWrapper = cAlloc(ComponentWrapper) catch return GameObjectError.ComponentWrapperAllocationFailed;

        // Initialize new component
        n_component.* = ComponentWrapper.create(self, TComponent) catch {
            cFree(n_component);
            return GameObjectError.ComponentWrapperCreationFailed;
        };

        // Add component to game object
        self.components.put(typeId(TComponent), n_component) catch {
            n_component.destroy() catch return GameObjectError.ComponentWrapperDestroyFailed;
            cFree(n_component);
            return GameObjectError.ComponentWrapperAppendFailed;
        };

        // Try to start and bind events for new component
        n_component.start() catch {
            n_component.destroy() catch return GameObjectError.ComponentWrapperDestroyFailed;
            cFree(n_component);
            _ = self.components.remove(typeId(TComponent));
            return GameObjectError.ComponentWrapperStartFailed;
        };

        return n_component;
    }

    /// Removes component from game object by component type
    ///
    /// # Arguments
    /// - `TComponent`: Component type
    ///
    /// # Errors
    /// - `ComponentWrapperDoesNotExist`: Component does not exist
    /// - `ComponentWrapperDestroyFailed`: Failed to destroy component
    pub fn removeComponentByType(self: *GameObject, comptime TComponent: type) GameObjectError!void {
        const component_type_id: TypeId = typeId(TComponent);
        try self.removeComponentByTypeId(component_type_id);
    }

    /// Removes component from game object by component type id
    ///
    /// # Arguments
    /// - `component_type_id`: Component type id
    ///
    /// # Errors
    /// - `ComponentWrapperDoesNotExist`: Component does not exist
    /// - `ComponentWrapperDestroyFailed`: Failed to destroy component
    pub fn removeComponentByTypeId(self: *GameObject, component_type_id: TypeId) GameObjectError!void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Try to find component
        const component: ?*ComponentWrapper = self.components.get(component_type_id);
        if (component == null) {
            return GameObjectError.ComponentWrapperDoesNotExist;
        }

        // Remove component from game object
        const wasComponentFound = self.components.remove(component_type_id);
        if (!wasComponentFound) {
            return GameObjectError.ComponentWrapperDoesNotExist;
        }

        // Call destroy() on component to ensure all resources are freed
        if (component) |comp| {
            comp.destroy() catch {
                return GameObjectError.ComponentWrapperDestroyFailed;
            };

            cFree(comp);
        }
    }

    /// Returns component of type TComponent
    ///
    /// # Arguments
    /// - `TComponent`: Component type
    ///
    /// # Returns
    /// - `TComponent`: Component
    pub fn getComponent(self: *GameObject, comptime TComponent: type) ?*TComponent {
        const component_type_id: TypeId = typeId(TComponent);
        const component: ?*ComponentWrapper = self.findComponentWrapperByTypeId(component_type_id);

        if (component) |cmp| {
            return cmp.getComponentAsType(TComponent);
        }

        return null;
    }

    pub fn setId(self: *GameObject, id: usize) void {
        self.unique_id = id;
    }

    // --------------------------- HELPER FUNCTIONS --------------------------- //
    fn findComponentWrapperByTypeId(self: *GameObject, component_type_id: TypeId) ?*ComponentWrapper {
        return self.components.get(component_type_id);
    }
};

pub const GameObjectError = error{
    ComponentWrapperAllocationFailed,
    ComponentWrapperCreationFailed,
    ComponentWrapperAppendFailed,
    ComponentWrapperDestroyFailed,
    ComponentWrapperStartFailed,
    ComponentWrapperDoesNotExist,
};
