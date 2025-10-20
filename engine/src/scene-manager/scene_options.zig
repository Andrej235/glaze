/// Configuration options for a scene.
///
/// `SceneOptions` defines key parameters that control the world layout,
/// spatial partitioning, and parallelization settings for the physics engine.
///
/// Each field can be customized at compile time. Invalid configurations
/// will trigger descriptive `@compileError` messages to prevent runtime issues.
///
/// ## Fields
///
/// ### name
/// A human-readable unique scene identifier.
/// Used for setting the active scene and logging.
///
/// ### world_width
/// The total horizontal size of the simulated world, in world units.
/// Must satisfy the following constraints:
/// - `world_width > 0`
/// - `world_width <= 5000`
/// - Must be divisible by `spatial_hash_cell_size`
///
/// This defines how far the physics engine will search for rigid bodies and
/// colliders. Objects positioned outside half of this range in either direction
/// may behave unpredictably and impact performance.
///
/// Default: `1024`
///
/// ### world_height
/// The total vertical size of the simulated world, in world units.
/// Must satisfy the same constraints as `world_width`:
/// - `world_height > 0`
/// - `world_height <= 5000`
/// - Must be divisible by `spatial_hash_cell_size`
///
/// Default: `1024`
///
/// ### spatial_hash_cell_size
/// The size (in world units) of each cell in the spatial hash grid used for
/// broad-phase collision detection.
///
/// Must satisfy:
/// - `spatial_hash_cell_size > 0`
/// - `spatial_hash_cell_size <= 32`
/// - Must be a power of two
///
/// Both `world_width` and `world_height` must be divisible by this value.
///
/// Default: `2`
///
/// ### physics_engine_thread_count
/// The number of worker threads used by the physics engine.
/// Determines how many concurrent threads handle physics updates.
///
/// Must satisfy:
/// - `0 < physics_engine_thread_count <= 16`
///
/// Default: `2`
///
/// ### bit_map_item_size_in_bits
/// The bit-width of items used in internal bitsets (e.g. for cell activity or
/// occupancy tracking). This determines the integer type used internally:
///
/// | Bits | Type |
/// |------|------|
/// | 1    | `u1` |
/// | 2    | `u2` |
/// | 4    | `u4` |
/// | 8    | `u8` |
/// | 16   | `u16` |
/// | 32   | `u32` |
/// | 64   | `u64` |
/// | 128  | `u128` |
/// | 256  | `u256` |
///
/// Any other value will trigger a compile error.
///
/// - The bitset item size should generally stay at **64 bits**, which balances
///   performance and memory efficiency on most systems.
/// - **Smaller values** may benefit **small worlds** or **tightly packed scenes**,
///   improving cache locality and reducing wasted bits.
/// - Conversely, **larger values** can be more efficient for **large, sparse scenes**,
///   minimizing the number of array items and improving traversal performance.
///
/// Default: `64`
///
/// ## Notes
///
/// - `world_width` and `world_height` define the simulation bounds; objects
///   outside `(±width / 2, ±height / 2)` are considered out of range.
/// - Choosing a small `spatial_hash_cell_size` increases accuracy but reduces
///   performance.
/// - The bitset item size should generally remain at `64` unless you have a
///   specific reason to optimize for memory or sparsity.
pub const SceneOptions = struct {
    /// Scene name, used for setting the active scene and logging.
    name: []const u8,

    /// Total world width in world units (1–5000, must be divisible by `spatial_hash_cell_size`).
    world_width: u16 = 1024,

    /// Total world height in world units (1–5000, must be divisible by `spatial_hash_cell_size`).
    world_height: u16 = 1024,

    /// Size of each spatial hash cell (must be a power of two between 1 and 32).
    spatial_hash_cell_size: u8 = 2,

    /// Number of worker threads used by the physics engine (1–16).
    physics_engine_thread_count: usize = 2,

    /// Bit width of each bitset item (1, 2, 4, 8, 16, 32, 64, 128, or 256).
    /// Generally keep this at 64 bits, but smaller values may help small dense scenes,
    /// while larger values may help large sparse scenes.
    bit_map_item_size_in_bits: u16 = 64,
};
