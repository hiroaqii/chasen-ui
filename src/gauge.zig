const std = @import("std");
const chasen = @import("chasen");

/// A compact display-only metric gauge.
///
/// `Gauge` draws a label, an inline progress bar, and a value text on one row.
/// It does not own metric state, thresholds, formatting, animation, or update
/// timing. Applications decide what the metric means and pass the already
/// formatted value text to `view`.
pub const Gauge = struct {
    /// Initial values used when constructing a `Gauge`.
    pub const Options = struct {};

    /// Rendering options for `Gauge.view`.
    pub const ViewOptions = struct {
        /// Label drawn before the bar.
        label: []const u8 = "",
        /// Normalized progress. Non-NaN values are clamped into `0.0...1.0`.
        progress: f32 = 0.0,
        /// Already-formatted value text drawn after the bar.
        value_text: []const u8 = "",
        /// Minimum width reserved for the label.
        label_width: u16 = 10,
        /// Minimum width reserved for the value text.
        value_width: u16 = 5,
        /// Spaces between label, bar, and value.
        gap: u16 = 1,
        /// Glyph drawn before the bar cells.
        left_delimiter: []const u8 = "[",
        /// Glyph drawn after the bar cells.
        right_delimiter: []const u8 = "]",
        /// Glyph used for filled bar cells.
        ///
        /// `Gauge` currently assumes this glyph occupies one display cell.
        filled: []const u8 = "|",
        /// Glyph used for empty bar cells.
        ///
        /// `Gauge` currently assumes this glyph occupies one display cell.
        empty: []const u8 = ".",
        /// Style used for the label.
        label_style: chasen.TextStyle = .{},
        /// Style used for delimiters.
        delimiter_style: chasen.TextStyle = .{ .dim = true },
        /// Style used for filled cells.
        filled_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for empty cells.
        empty_style: chasen.TextStyle = .{ .dim = true },
        /// Style used for value text.
        value_style: chasen.TextStyle = .{},
    };

    /// Create a gauge.
    pub fn init(opts: Options) Gauge {
        _ = opts;
        return .{};
    }

    /// Return how many bar cells can fit after label/value reservations.
    pub fn barWidth(total_width: u16, opts: ViewOptions) u16 {
        const label_width = reservedTextWidth(opts.label, opts.label_width);
        const value_width = reservedTextWidth(opts.value_text, opts.value_width);
        const left_width = chasen.text.displayWidth(opts.left_delimiter);
        const right_width = chasen.text.displayWidth(opts.right_delimiter);
        const fixed = label_width +| opts.gap +| left_width +| right_width +| opts.gap +| value_width;
        return total_width -| fixed;
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

    /// Draw the gauge into the provided one-line surface region.
    pub fn view(self: *const Gauge, surface: *chasen.Surface, opts: ViewOptions) void {
        _ = self;
        const width = surface.size().width;
        if (width == 0) return;

        const label_width = reservedTextWidth(opts.label, opts.label_width);
        const value_width = reservedTextWidth(opts.value_text, opts.value_width);
        const bar_width = barWidth(width, opts);

        var cursor: u16 = 0;
        drawText(surface, &cursor, opts.label, opts.label_style, width);
        padTo(surface, &cursor, label_width, width);
        drawSpaces(surface, &cursor, opts.gap, width);
        drawText(surface, &cursor, opts.left_delimiter, opts.delimiter_style, width);

        const filled_count = filledCount(opts.progress, bar_width);
        var index: u16 = 0;
        while (index < bar_width and cursor < width) : (index += 1) {
            if (index < filled_count) {
                drawText(surface, &cursor, opts.filled, opts.filled_style, width);
            } else {
                drawText(surface, &cursor, opts.empty, opts.empty_style, width);
            }
        }

        drawText(surface, &cursor, opts.right_delimiter, opts.delimiter_style, width);
        drawSpaces(surface, &cursor, opts.gap, width);
        drawText(surface, &cursor, opts.value_text, opts.value_style, @min(width, cursor +| value_width));
    }
};

fn reservedTextWidth(text: []const u8, minimum_width: u16) u16 {
    return @max(minimum_width, chasen.text.displayWidth(text));
}

fn drawText(surface: *chasen.Surface, cursor: *u16, text: []const u8, style: chasen.TextStyle, width: u16) void {
    if (text.len == 0 or cursor.* >= width) return;
    _ = surface.textAt(cursor.*, 0, text, style);
    cursor.* +|= chasen.text.displayWidth(text);
}

fn drawSpaces(surface: *chasen.Surface, cursor: *u16, count: u16, width: u16) void {
    var index: u16 = 0;
    while (index < count and cursor.* < width) : (index += 1) {
        _ = surface.textAt(cursor.*, 0, " ", .{});
        cursor.* +|= 1;
    }
}

fn padTo(surface: *chasen.Surface, cursor: *u16, target: u16, width: u16) void {
    while (cursor.* < target and cursor.* < width) {
        _ = surface.textAt(cursor.*, 0, " ", .{});
        cursor.* +|= 1;
    }
}

fn clamp01(value: f32) f32 {
    if (value <= 0.0) return 0.0;
    if (value >= 1.0) return 1.0;
    return value;
}

test "Gauge initializes from options" {
    const gauge = Gauge.init(.{});
    _ = gauge;
}

test "Gauge barWidth subtracts label, delimiters, gaps, and value" {
    const opts = Gauge.ViewOptions{
        .label = "CPU",
        .value_text = "42%",
        .label_width = 6,
        .value_width = 4,
        .gap = 1,
    };

    try std.testing.expectEqual(@as(u16, 18), Gauge.barWidth(32, opts));
}

test "Gauge barWidth saturates when reservations exceed width" {
    const opts = Gauge.ViewOptions{
        .label = "Very long label",
        .value_text = "100%",
        .label_width = 20,
        .value_width = 8,
        .gap = 2,
    };

    try std.testing.expectEqual(@as(u16, 0), Gauge.barWidth(10, opts));
}

test "Gauge filledCount maps progress to filled cells" {
    try std.testing.expectEqual(@as(u16, 0), Gauge.filledCount(0.0, 4));
    try std.testing.expectEqual(@as(u16, 1), Gauge.filledCount(0.25, 4));
    try std.testing.expectEqual(@as(u16, 2), Gauge.filledCount(0.5, 4));
    try std.testing.expectEqual(@as(u16, 4), Gauge.filledCount(1.0, 4));
}

test "Gauge filledCount clamps progress and handles NaN" {
    try std.testing.expectEqual(@as(u16, 0), Gauge.filledCount(-1.0, 4));
    try std.testing.expectEqual(@as(u16, 4), Gauge.filledCount(2.0, 4));
    try std.testing.expectEqual(@as(u16, 0), Gauge.filledCount(std.math.nan(f32), 4));
}
