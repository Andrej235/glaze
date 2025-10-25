pub const Attribute = struct {
    name: []const u8,
    value: []const u8,
    type: Type,

    const Type = enum { string, dynamic };

    pub fn create(name: []const u8, value: []const u8, attr_type: Type) Attribute {
        return Attribute{ .name = name, .value = value, .type = attr_type };
    }
};
