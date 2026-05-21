const std = @import("std");
const chasen = @import("chasen");

/// A small display-only rating component.
///
/// `Rating` is allocation-free and stateless. It does not decide what rating
/// values mean, how they are validated, or when they are saved. Applications
/// pass the already-decided filled and total counts to `view`.
pub const Rating = struct {
    /// Initial values used when constructing a `Rating`.
    pub const Options = struct {};

    /// Rendering options for `Rating.view`.
    pub const ViewOptions = struct {
        /// Number of filled rating items to draw.
        ///
        /// Values greater than `total_count` are clamped while rendering.
        filled_count: u16 = 0,
        /// Total number of rating items to draw.
        total_count: u16 = 5,
        /// Glyph used for filled rating items.
        ///
        /// Use a one-display-cell glyph so each item remains evenly spaced.
        filled_glyph: []const u8 = "*",
        /// Glyph used for empty rating items.
        ///
        /// Use a one-display-cell glyph so each item remains evenly spaced.
        empty_glyph: []const u8 = "-",
        /// Gap between rating item glyphs.
        gap: u16 = 0,
        /// Style used for filled rating items.
        filled_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for empty rating items.
        empty_style: chasen.TextStyle = .{ .dim = true },
    };

    /// Create a rating component.
    pub fn init(opts: Options) Rating {
        _ = opts;
        return .{};
    }

    /// Return the filled item count clamped to `total_count`.
    pub fn clampedFilledCount(filled_count: u16, total_count: u16) u16 {
        return @min(filled_count, total_count);
    }

    /// Draw the rating into the provided one-line surface region.
    pub fn view(self: *const Rating, surface: *chasen.Surface, opts: ViewOptions) void {
        _ = self;
        const width = surface.size().width;
        if (width == 0) return;

        const filled_count = clampedFilledCount(opts.filled_count, opts.total_count);
        var index: u16 = 0;
        var item_col: u16 = 0;
        while (index < opts.total_count and item_col < width) : (index += 1) {
            if (index < filled_count) {
                _ = surface.borrowTextAt(item_col, 0, opts.filled_glyph, opts.filled_style);
                item_col +|= chasen.text.displayWidth(opts.filled_glyph);
            } else {
                _ = surface.borrowTextAt(item_col, 0, opts.empty_glyph, opts.empty_style);
                item_col +|= chasen.text.displayWidth(opts.empty_glyph);
            }

            if (index + 1 < opts.total_count) {
                item_col +|= opts.gap;
            }
        }
    }
};

test "Rating initializes from options" {
    const rating = Rating.init(.{});
    _ = rating;
}

test "Rating clampedFilledCount clamps to total count" {
    try std.testing.expectEqual(@as(u16, 0), Rating.clampedFilledCount(0, 5));
    try std.testing.expectEqual(@as(u16, 3), Rating.clampedFilledCount(3, 5));
    try std.testing.expectEqual(@as(u16, 5), Rating.clampedFilledCount(7, 5));
}

test "Rating clampedFilledCount handles zero total count" {
    try std.testing.expectEqual(@as(u16, 0), Rating.clampedFilledCount(3, 0));
}
