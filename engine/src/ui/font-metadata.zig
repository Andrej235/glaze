const BoundsF64 = struct {
    left: f64,
    bottom: f64,
    right: f64,
    top: f64,
};

pub const Glyph = struct {
    unicode: u32,
    advance: f64,
    planeBounds: ?BoundsF64 = null,
    atlasBounds: ?BoundsF64 = null,
    uvBounds: ?BoundsF64 = null,
};

const Atlas = struct {
    type: []const u8,
    distanceRange: f64,
    distanceRangeMiddle: f64,
    size: f64,
    width: i32,
    height: i32,
    yOrigin: []const u8,
};

const Metrics = struct {
    emSize: f64,
    lineHeight: f64,
    ascender: f64,
    descender: f64,
    underlineY: f64,
    underlineThickness: f64,
};

pub const FontMetadata = struct {
    atlas: Atlas,
    metrics: Metrics,
    glyphs: []Glyph,
};
