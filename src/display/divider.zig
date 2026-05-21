const std = @import("std");
const chasen = @import("chasen");

/// A small horizontal or vertical divider component.
///
/// `Divider` is display-only and allocation-free. It owns no state and only
/// draws a repeated one-cell glyph into the surface region passed to `view`.
/// Applications decide where dividers belong in the surrounding layout.
pub const Divider = struct {
    /// Direction in which the divider is drawn.
    pub const Direction = enum {
        /// Draw left to right on a single row.
        horizontal,
        /// Draw top to bottom in a single column.
        vertical,
    };

    /// Initial values used when constructing a `Divider`.
    pub const Options = struct {};

    /// Rendering options for `Divider.view`.
    pub const ViewOptions = struct {
        /// Direction in which the divider should be drawn.
        direction: Direction = .horizontal,
        /// Optional glyph used for each cell.
        ///
        /// When omitted, horizontal dividers use `-` and vertical dividers use
        /// `|`. `Divider` currently assumes the glyph occupies one display
        /// cell.
        glyph: ?[]const u8 = null,
        /// Style used for the divider glyph.
        style: chasen.TextStyle = .{ .dim = true },
    };

    /// Create a divider.
    pub fn init(opts: Options) Divider {
        _ = opts;
        return .{};
    }

    /// Return the default glyph for the given direction.
    pub fn defaultGlyph(direction: Direction) []const u8 {
        return switch (direction) {
            .horizontal => "-",
            .vertical => "|",
        };
    }

    /// Draw the divider across the provided one-row or one-column surface region.
    pub fn view(self: *const Divider, surface: *chasen.Surface, opts: ViewOptions) void {
        _ = self;
        const glyph = opts.glyph orelse defaultGlyph(opts.direction);
        const size = surface.size();
        switch (opts.direction) {
            .horizontal => {
                var col: u16 = 0;
                while (col < size.width) : (col += 1) {
                    _ = surface.borrowTextAt(col, 0, glyph, opts.style);
                }
            },
            .vertical => {
                var row: u16 = 0;
                while (row < size.height) : (row += 1) {
                    _ = surface.borrowTextAt(0, row, glyph, opts.style);
                }
            },
        }
    }
};

test "Divider initializes from options" {
    const divider = Divider.init(.{});
    _ = divider;
}

test "Divider defaultGlyph returns direction-specific ASCII glyphs" {
    try std.testing.expectEqualStrings("-", Divider.defaultGlyph(.horizontal));
    try std.testing.expectEqualStrings("|", Divider.defaultGlyph(.vertical));
}
