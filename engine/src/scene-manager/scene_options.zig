pub const SceneOptions = struct {
    name: []const u8,
    world_width: u16 = 1024,
    world_height: u16 = 1024,
    spatial_hash_cell_size: u8 = 2,
    physics_engine_thread_count: usize = 2,
    bit_map_item_size_in_bits: u16 = 64,
};
