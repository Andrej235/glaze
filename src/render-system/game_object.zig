const std = @import("std");

pub const GameObject = struct {
    id: usize,

    component_ptr: ?*anyopaque,
    component_deinit_fptr: ?*const fn(*anyopaque) anyerror!void,

    script_ptr: ?*anyopaque,
    script_deinit_fptr: ?*const fn(*anyopaque) anyerror!void,

    pub fn init() GameObject {
        return GameObject{
            .id = 0,
            .component_ptr = null,
            .component_deinit_fptr = null,
            .script_ptr = null,
            .script_deinit_fptr = null,
        };
    }

    pub fn setEntity(self: *GameObject, comptime TEntity: type, entity: *TEntity) void {
        if (!@hasDecl(TEntity, "render")) @compileError("TEntity must implement render()");
        if (!@hasDecl(TEntity, "deinit")) @compileError("TEntity must implement deinit()");

        self.component_ptr = entity;
        self.component_deinit_fptr = deinitWrapper(TEntity);
    }

    pub fn setScript(self: *GameObject, comptime TScript: type, script: *TScript) !void {
        if (!@hasDecl(TScript, "start")) @compileError("TScript must implement start()");
        if (!@hasDecl(TScript, "update")) @compileError("TScript must implement update()");
        if (!@hasDecl(TScript, "deinit")) @compileError("TScript must implement deinit()");

        self.script_ptr = script;
        self.script_deinit_fptr = deinitWrapper(TScript);

        try script.start();
    }

    fn deinitWrapper(comptime T: type) fn(*anyopaque) anyerror!void {
        return struct {
            fn call(ptr: *anyopaque) !void {
                const typed: *T = @ptrCast(@alignCast(ptr));
                try typed.deinit();
            }
        }.call;
    }

    pub fn deinit(self: *GameObject) !void {
        std.debug.print("\nCalled deinit()\n", .{});

        if (self.script_ptr) |ptr| {
            if (self.script_deinit_fptr) |fn_ptr| {
                try fn_ptr(ptr);
            }
        }

        if (self.component_ptr) |ptr| {
            if (self.component_deinit_fptr) |fn_ptr| {
                try fn_ptr(ptr);
            }
        }
    }

    pub fn setId(self: *GameObject, id: usize) void {
        self.id = id;
    }
};
