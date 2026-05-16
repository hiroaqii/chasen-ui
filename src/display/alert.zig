const std = @import("std");
const chasen = @import("chasen");

/// A small display-only alert component.
///
/// `Alert` is allocation-free and stateless. It does not decide severity,
/// dismissal, lifetime, or message ownership. Applications choose the marker,
/// title, body, styles, and visibility policy, then pass those values to view.
pub const Alert = struct {
    /// Initial values used when constructing an `Alert`.
    pub const Options = struct {};

    /// Rendering options for `Alert.view`.
    pub const ViewOptions = struct {
        /// Optional leading marker, such as a severity glyph.
        marker: []const u8 = "",
        /// Alert title shown on the header row.
        title: []const u8 = "",
        /// Optional one-line body text.
        ///
        /// Richer wrapping or multiple paragraphs should be prepared by the
        /// application or composed with `Paragraph`.
        body: []const u8 = "",
        /// Gap between marker and title when both are present.
        gap: u16 = 1,
        /// Optional body start column within the alert region.
        ///
        /// When null, a body below a marker/title header aligns under the
        /// title. Body-only alerts start at column zero.
        body_col: ?u16 = null,
        /// Style used for the marker.
        marker_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for the title.
        title_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for body text.
        body_style: chasen.TextStyle = .{},
    };

    /// Create an alert component.
    pub fn init(opts: Options) Alert {
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

    /// Return how many rows the alert content occupies before clipping.
    pub fn contentHeight(opts: ViewOptions) u16 {
        var rows: u16 = 0;
        if (hasHeader(opts)) rows += 1;
        if (opts.body.len > 0) rows += 1;
        return rows;
    }

    /// Return the default body start column within the alert region.
    pub fn defaultBodyCol(opts: ViewOptions) u16 {
        if (opts.body_col) |col| return col;
        if (!hasHeader(opts)) return 0;
        if (opts.marker.len > 0 and opts.title.len > 0) {
            return chasen.text.displayWidth(opts.marker) +| opts.gap;
        }
        return 0;
    }

    /// Draw the alert into the provided clipped surface region.
    pub fn view(self: *const Alert, surface: *chasen.Surface, opts: ViewOptions) void {
        _ = self;
        const size = surface.size();
        const width = size.width;
        const height = size.height;
        if (width == 0 or height == 0) return;

        var row: u16 = 0;
        if (hasHeader(opts)) {
            var cursor: u16 = 0;
            drawText(surface, &cursor, 0, opts.marker, opts.marker_style, width);
            if (opts.marker.len > 0 and opts.title.len > 0) {
                drawSpaces(surface, &cursor, 0, opts.gap, opts.title_style, width);
            }
            drawText(surface, &cursor, 0, opts.title, opts.title_style, width);
            row += 1;
        }

        if (opts.body.len > 0 and row < height) {
            var cursor = @min(defaultBodyCol(opts), width);
            drawText(surface, &cursor, row, opts.body, opts.body_style, width);
        }
    }
};

fn hasHeader(opts: Alert.ViewOptions) bool {
    return opts.marker.len > 0 or opts.title.len > 0;
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

test "Alert initializes from options" {
    const alert = Alert.init(.{});
    _ = alert;
}

test "Alert headerWidth includes marker title and gap" {
    try std.testing.expectEqual(@as(u16, 8), Alert.headerWidth(.{
        .marker = "!",
        .title = "Alert",
        .gap = 2,
    }));
}

test "Alert headerWidth omits gap when marker or title is empty" {
    try std.testing.expectEqual(@as(u16, 5), Alert.headerWidth(.{
        .marker = "",
        .title = "Title",
        .gap = 4,
    }));
    try std.testing.expectEqual(@as(u16, 1), Alert.headerWidth(.{
        .marker = "!",
        .title = "",
        .gap = 4,
    }));
}

test "Alert contentHeight counts present header and body rows" {
    try std.testing.expectEqual(@as(u16, 0), Alert.contentHeight(.{}));
    try std.testing.expectEqual(@as(u16, 1), Alert.contentHeight(.{ .title = "Title" }));
    try std.testing.expectEqual(@as(u16, 1), Alert.contentHeight(.{ .body = "Body" }));
    try std.testing.expectEqual(@as(u16, 2), Alert.contentHeight(.{ .title = "Title", .body = "Body" }));
}

test "Alert defaultBodyCol aligns under title when marker and title are present" {
    try std.testing.expectEqual(@as(u16, 2), Alert.defaultBodyCol(.{
        .marker = "!",
        .title = "Title",
        .gap = 1,
    }));
    try std.testing.expectEqual(@as(u16, 0), Alert.defaultBodyCol(.{ .title = "Title" }));
    try std.testing.expectEqual(@as(u16, 4), Alert.defaultBodyCol(.{ .title = "Title", .body_col = 4 }));
    try std.testing.expectEqual(@as(u16, 3), Alert.defaultBodyCol(.{ .body = "Body", .body_col = 3 }));
}
