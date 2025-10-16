pub const SceneOptions = struct {
    name: []const u8,
    world_size_x: u16 = 1000,
    world_size_y: u16 = 500,
    spatial_hash_cell_size: u8 = 2,
};
