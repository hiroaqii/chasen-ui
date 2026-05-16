const std = @import("std");
const chasen = @import("chasen");

/// A compact display-only toast notification chrome.
///
/// `Toast` draws one transient notification with optional marker, title, body,
/// and lifetime progress. It does not own visibility, queues, timers,
/// dismissal policy, placement policy, or message storage. Applications decide
/// when a toast is visible and pass borrowed text to each `view` call.
pub const Toast = struct {
    /// Initial values used when constructing a `Toast`.
    pub const Options = struct {};

    /// Rendering options for `Toast.view`.
    pub const ViewOptions = struct {
        /// Surface column where the toast should start.
        col: u16 = 0,
        /// Surface row where the toast should start.
        row: u16 = 0,
        /// Optional width of the clipped toast region.
        width: ?u16 = null,
        /// Optional height of the clipped toast region.
        height: ?u16 = null,
        /// Optional leading marker, such as a severity glyph.
        marker: []const u8 = "",
        /// Toast title shown on the header row.
        title: []const u8 = "",
        /// Optional one-line body text.
        body: []const u8 = "",
        /// Optional normalized lifetime progress.
        ///
        /// When present and height allows it, the toast draws a progress row.
        progress: ?f32 = null,
        /// Padding inside the toast region.
        padding: u16 = 1,
        /// Gap between marker and title when both are present.
        gap: u16 = 1,
        /// Glyph used for filled progress cells.
        ///
        /// `Toast` currently assumes this glyph occupies one display cell.
        progress_filled: []const u8 = "|",
        /// Glyph used for empty progress cells.
        ///
        /// `Toast` currently assumes this glyph occupies one display cell.
        progress_empty: []const u8 = ".",
        /// Style used to fill the toast background.
        fill_style: chasen.TextStyle = .{},
        /// Style used for the marker.
        marker_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for the title.
        title_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for body text.
        body_style: chasen.TextStyle = .{},
        /// Style used for filled progress cells.
        progress_filled_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for empty progress cells.
        progress_empty_style: chasen.TextStyle = .{ .dim = true },
    };

    /// Create a toast component.
    pub fn init(opts: Options) Toast {
        _ = opts;
        return .{};
    }

    /// Return the display width of the header before clipping.
    pub fn headerWidth(opts: ViewOptions) u16 {
        var width: u16 = chasen.text.displayWidth(opts.marker);
        if (opts.marker.len > 0 and opts.title.len > 0) {
            width +|= opts.gap;
        }
        width +|= chasen.text.displayWidth(opts.title);
        return width;
    }

    /// Return how many rows the toast content occupies before clipping.
    pub fn contentHeight(opts: ViewOptions) u16 {
        var rows: u16 = 0;
        if (hasHeader(opts)) rows +|= 1;
        if (opts.body.len > 0) rows +|= 1;
        if (opts.progress != null) rows +|= 1;
        return rows;
    }

    /// Return how many cells should be filled for the given progress and width.
    pub fn progressFilledCount(progress: f32, width: u16) u16 {
        if (width == 0 or std.math.isNan(progress)) return 0;

        const p = clamp01(progress);
        if (p <= 0.0) return 0;
        if (p >= 1.0) return width;

        const filled_float = @floor(p * @as(f32, @floatFromInt(width)));
        const filled: u16 = @intFromFloat(filled_float);
        return @min(filled, width);
    }

    /// Draw the toast into a clipped region.
    pub fn view(self: *const Toast, surface: *chasen.Surface, opts: ViewOptions) void {
        _ = self;
        const width = opts.width orelse availableWidth(surface, opts.col);
        const height = opts.height orelse @max(contentHeight(opts), 1);
        if (width == 0 or height == 0) return;

        var child = surface.child(.{
            .col = opts.col,
            .row = opts.row,
            .width = width,
            .height = height,
        });
        fillRegion(&child, width, height, opts.fill_style);

        var row: u16 = 0;
        const content_col = @min(opts.padding, width);
        const content_width = width -| opts.padding *| 2;

        if (hasHeader(opts) and row < height) {
            var cursor = content_col;
            drawText(&child, &cursor, row, opts.marker, opts.marker_style, width);
            if (opts.marker.len > 0 and opts.title.len > 0) {
                drawSpaces(&child, &cursor, row, opts.gap, opts.title_style, width);
            }
            drawText(&child, &cursor, row, opts.title, opts.title_style, width);
            row +|= 1;
        }

        if (opts.body.len > 0 and row < height) {
            var cursor = content_col;
            drawText(&child, &cursor, row, opts.body, opts.body_style, width);
            row +|= 1;
        }

        if (opts.progress) |progress| {
            if (row < height and content_width > 0) {
                drawProgress(&child, content_col, row, content_width, progress, opts);
            }
        }
    }
};

fn hasHeader(opts: Toast.ViewOptions) bool {
    return opts.marker.len > 0 or opts.title.len > 0;
}

fn drawProgress(surface: *chasen.Surface, col: u16, row: u16, width: u16, progress: f32, opts: Toast.ViewOptions) void {
    const filled_count = Toast.progressFilledCount(progress, width);
    var index: u16 = 0;
    var cursor = col;
    while (index < width) : (index += 1) {
        if (index < filled_count) {
            drawText(surface, &cursor, row, opts.progress_filled, opts.progress_filled_style, col +| width);
        } else {
            drawText(surface, &cursor, row, opts.progress_empty, opts.progress_empty_style, col +| width);
        }
    }
}

fn fillRegion(surface: *chasen.Surface, width: u16, height: u16, style: chasen.TextStyle) void {
    var row: u16 = 0;
    while (row < height) : (row += 1) {
        var col: u16 = 0;
        while (col < width) : (col += 1) {
            _ = surface.textAt(col, row, " ", style);
        }
    }
}

fn drawText(surface: *chasen.Surface, cursor: *u16, row: u16, text: []const u8, style: chasen.TextStyle, width: u16) void {
    if (text.len == 0 or cursor.* >= width) return;
    _ = surface.textAt(cursor.*, row, text, style);
    cursor.* +|= chasen.text.displayWidth(text);
}

fn drawSpaces(surface: *chasen.Surface, cursor: *u16, row: u16, count: u16, style: chasen.TextStyle, width: u16) void {
    var index: u16 = 0;
    while (index < count and cursor.* < width) : (index += 1) {
        _ = surface.textAt(cursor.*, row, " ", style);
        cursor.* +|= 1;
    }
}

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

test "Toast initializes from options" {
    const toast = Toast.init(.{});
    _ = toast;
}

test "Toast headerWidth includes marker title and gap" {
    try std.testing.expectEqual(@as(u16, 8), Toast.headerWidth(.{
        .marker = "!",
        .title = "Saved",
        .gap = 2,
    }));
}

test "Toast headerWidth omits gap when marker or title is empty" {
    try std.testing.expectEqual(@as(u16, 5), Toast.headerWidth(.{ .title = "Saved", .gap = 4 }));
    try std.testing.expectEqual(@as(u16, 1), Toast.headerWidth(.{ .marker = "!", .gap = 4 }));
}

test "Toast contentHeight counts header body and progress rows" {
    try std.testing.expectEqual(@as(u16, 0), Toast.contentHeight(.{}));
    try std.testing.expectEqual(@as(u16, 1), Toast.contentHeight(.{ .title = "Saved" }));
    try std.testing.expectEqual(@as(u16, 1), Toast.contentHeight(.{ .body = "Done" }));
    try std.testing.expectEqual(@as(u16, 1), Toast.contentHeight(.{ .progress = 0.5 }));
    try std.testing.expectEqual(@as(u16, 3), Toast.contentHeight(.{
        .title = "Saved",
        .body = "Settings updated",
        .progress = 0.5,
    }));
}

test "Toast progressFilledCount maps progress to filled cells" {
    try std.testing.expectEqual(@as(u16, 0), Toast.progressFilledCount(0.0, 4));
    try std.testing.expectEqual(@as(u16, 1), Toast.progressFilledCount(0.25, 4));
    try std.testing.expectEqual(@as(u16, 2), Toast.progressFilledCount(0.5, 4));
    try std.testing.expectEqual(@as(u16, 4), Toast.progressFilledCount(1.0, 4));
}

test "Toast progressFilledCount clamps progress and handles NaN" {
    try std.testing.expectEqual(@as(u16, 0), Toast.progressFilledCount(-1.0, 4));
    try std.testing.expectEqual(@as(u16, 4), Toast.progressFilledCount(2.0, 4));
    try std.testing.expectEqual(@as(u16, 0), Toast.progressFilledCount(std.math.nan(f32), 4));
}
