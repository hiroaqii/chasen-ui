const std = @import("std");
const chasen = @import("chasen");

/// A small horizontal progress bar component.
///
/// `ProgressBar` is display-only and allocation-free. It does not own
/// transition state, schedule frames, or call `ctx.requestFrame()`.
/// Applications pass a normalized progress value to `view`, usually from app
/// state or an animation helper.
pub const ProgressBar = struct {
    /// Initial values used when constructing a `ProgressBar`.
    pub const Options = struct {};

    /// Rendering options for `ProgressBar.view`.
    pub const ViewOptions = struct {
        /// Surface column where the progress bar should be drawn.
        col: u16 = 0,
        /// Surface row where the progress bar should be drawn.
        row: u16 = 0,
        /// Optional width of the clipped one-line progress bar region.
        width: ?u16 = null,
        /// Normalized progress. Non-NaN values are clamped into `0.0...1.0`.
        progress: f32 = 0.0,
        /// Glyph used for filled cells.
        ///
        /// `ProgressBar` currently assumes this glyph occupies one display
        /// cell.
        filled: []const u8 = "|",
        /// Glyph used for empty cells.
        ///
        /// `ProgressBar` currently assumes this glyph occupies one display
        /// cell.
        empty: []const u8 = ".",
        /// Style used for filled cells.
        filled_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for empty cells.
        empty_style: chasen.TextStyle = .{ .dim = true },
    };

    /// Create a progress bar.
    pub fn init(opts: Options) ProgressBar {
        _ = opts;
        return .{};
    }

    /// Return how many cells should be filled for the given progress and width.
    ///
    /// Non-NaN progress values are clamped into `0.0...1.0`. `NaN` progress and
    /// zero width return `0`.
    pub fn filledCount(progress: f32, width: u16) u16 {
        if (width == 0 or std.math.isNan(progress)) return 0;

        const p = clamp01(progress);
        if (p <= 0.0) return 0;
        if (p >= 1.0) return width;

        const filled_float = @floor(p * @as(f32, @floatFromInt(width)));
        const filled: u16 = @intFromFloat(filled_float);
        return @min(filled, width);
    }

    /// Draw the progress bar into a one-line region.
    pub fn view(self: *const ProgressBar, surface: *chasen.Surface, opts: ViewOptions) void {
        _ = self;
        const width = opts.width orelse availableWidth(surface, opts.col);
        if (width == 0) return;

        var child = surface.child(.{
            .col = opts.col,
            .row = opts.row,
            .width = width,
            .height = 1,
        });

        const filled_count = filledCount(opts.progress, width);
        var col: u16 = 0;
        while (col < width) : (col += 1) {
            if (col < filled_count) {
                _ = child.textAt(col, 0, opts.filled, opts.filled_style);
            } else {
                _ = child.textAt(col, 0, opts.empty, opts.empty_style);
            }
        }
    }
};

fn clamp01(value: f32) f32 {
    if (value <= 0.0) return 0.0;
    if (value >= 1.0) return 1.0;
    return value;
}

fn availableWidth(surface: *chasen.Surface, col: u16) u16 {
    const size = surface.size();
    if (col >= size.width) return 0;
    return size.width - col;
}

test "ProgressBar initializes from options" {
    const bar = ProgressBar.init(.{});
    _ = bar;
}

test "ProgressBar filledCount maps progress to filled cells" {
    try std.testing.expectEqual(@as(u16, 0), ProgressBar.filledCount(0.0, 4));
    try std.testing.expectEqual(@as(u16, 1), ProgressBar.filledCount(0.25, 4));
    try std.testing.expectEqual(@as(u16, 2), ProgressBar.filledCount(0.5, 4));
    try std.testing.expectEqual(@as(u16, 3), ProgressBar.filledCount(0.75, 4));
    try std.testing.expectEqual(@as(u16, 4), ProgressBar.filledCount(1.0, 4));
}

test "ProgressBar filledCount clamps progress" {
    try std.testing.expectEqual(@as(u16, 0), ProgressBar.filledCount(-1.0, 4));
    try std.testing.expectEqual(@as(u16, 4), ProgressBar.filledCount(2.0, 4));
}

test "ProgressBar filledCount returns width only at completed progress" {
    try std.testing.expectEqual(@as(u16, 2), ProgressBar.filledCount(0.99, 3));
    try std.testing.expectEqual(@as(u16, 3), ProgressBar.filledCount(1.0, 3));
}

test "ProgressBar filledCount advances only after crossing each cell threshold" {
    try std.testing.expectEqual(@as(u16, 0), ProgressBar.filledCount(0.249, 4));
    try std.testing.expectEqual(@as(u16, 1), ProgressBar.filledCount(0.25, 4));
}

test "ProgressBar filledCount handles zero width and NaN progress" {
    try std.testing.expectEqual(@as(u16, 0), ProgressBar.filledCount(1.0, 0));
    try std.testing.expectEqual(@as(u16, 0), ProgressBar.filledCount(std.math.nan(f32), 4));
}
