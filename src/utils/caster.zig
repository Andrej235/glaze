/// Casts anyopaque into a pointer to T.
/// Throws NullPointer if value is null
pub fn castFromNullableAnyopaque(comptime T: type, value: ?*anyopaque) !*T {
    if (value) |ptr| {
        return @ptrCast(@alignCast(ptr));
    } else {
        return error.NullPointer;
    }
}

/// Casts a pointer to T into anyopaque
pub fn castTPointerIntoAnyopaque(comptime T: type, value: *T) *anyopaque {
    return @ptrCast(@alignCast(value));
}