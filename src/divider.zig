const std = @import("std");
const chasen = @import("chasen");

/// A small horizontal or vertical divider component.
///
/// `Divider` is display-only and allocation-free. It owns no state and only
/// draws a repeated one-cell glyph into the region selected by `ViewOptions`.
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
        /// Surface column where the divider should start.
        col: u16 = 0,
        /// Surface row where the divider should start.
        row: u16 = 0,
        /// Direction in which the divider should be drawn.
        direction: Direction = .horizontal,
        /// Optional number of cells to draw.
        ///
        /// When omitted, a horizontal divider uses the remaining surface width
        /// and a vertical divider uses the remaining surface height.
        /// When provided, this is the requested length; drawing may still be
        /// clipped by the parent surface.
        length: ?u16 = null,
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

    /// Draw the divider into a one-row or one-column region.
    pub fn view(self: *const Divider, surface: *chasen.Surface, opts: ViewOptions) void {
        _ = self;
        const length = opts.length orelse availableLength(surface, opts.col, opts.row, opts.direction);
        if (length == 0) return;

        const glyph = opts.glyph orelse defaultGlyph(opts.direction);
        switch (opts.direction) {
            .horizontal => {
                var child = surface.child(.{
                    .col = opts.col,
                    .row = opts.row,
                    .width = length,
                    .height = 1,
                });
                var col: u16 = 0;
                while (col < length) : (col += 1) {
                    _ = child.textAt(col, 0, glyph, opts.style);
                }
            },
            .vertical => {
                var child = surface.child(.{
                    .col = opts.col,
                    .row = opts.row,
                    .width = 1,
                    .height = length,
                });
                var row: u16 = 0;
                while (row < length) : (row += 1) {
                    _ = child.textAt(0, row, glyph, opts.style);
                }
            },
        }
    }
};

fn availableLength(surface: *chasen.Surface, col: u16, row: u16, direction: Divider.Direction) u16 {
    const size = surface.size();
    return switch (direction) {
        .horizontal => if (col >= size.width) 0 else size.width - col,
        .vertical => if (row >= size.height) 0 else size.height - row,
    };
}

test "Divider initializes from options" {
    const divider = Divider.init(.{});
    _ = divider;
}

test "Divider defaultGlyph returns direction-specific ASCII glyphs" {
    try std.testing.expectEqualStrings("-", Divider.defaultGlyph(.horizontal));
    try std.testing.expectEqualStrings("|", Divider.defaultGlyph(.vertical));
}
