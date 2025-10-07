const std = @import("std");
pub const TypeId = u32;

/// Returns unique id for a type
pub fn typeId(T: type) TypeId {
    const name = @typeName(T);
    var hash: u32 = 2166136261; // FNV-1a 32-bit offset
    
    for (name) |c| {
        const cc: u32 = @intCast(c);
        hash = (hash ^ cc) *% 16777619; // 32-bit FNV-1a prime
    }
    
    return hash;
}