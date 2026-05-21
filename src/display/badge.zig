const std = @import("std");
const chasen = @import("chasen");

/// A compact display-only badge component.
///
/// `Badge` is allocation-free and stateless. It does not decide whether text
/// represents a status, count, mode, tag, or severity. Applications choose the
/// text, optional marker, styles, and placement for each view call.
pub const Badge = struct {
    /// Initial values used when constructing a `Badge`.
    pub const Options = struct {};

    /// Rendering options for `Badge.view`.
    pub const ViewOptions = struct {
        /// Optional leading marker, such as a status glyph.
        marker: []const u8 = "",
        /// Badge text. The application decides its meaning.
        text: []const u8 = "",
        /// Gap between marker and text when both are present.
        gap: u16 = 1,
        /// Padding before marker/text.
        padding_left: u16 = 1,
        /// Padding after marker/text.
        padding_right: u16 = 1,
        /// Style used for the marker.
        marker_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for badge text.
        text_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for padding cells.
        padding_style: chasen.TextStyle = .{},
    };

    /// Create a badge component.
    pub fn init(opts: Options) Badge {
        _ = opts;
        return .{};
    }

    /// Return the display width of badge content before clipping.
    pub fn contentWidth(opts: ViewOptions) u16 {
        var width: u16 = opts.padding_left +| opts.padding_right;
        width +|= chasen.text.displayWidth(opts.marker);
        width +|= chasen.text.displayWidth(opts.text);
        if (opts.marker.len > 0 and opts.text.len > 0) {
            width +|= opts.gap;
        }
        return width;
    }

    /// Draw the badge into the provided one-line surface region.
    pub fn view(self: *const Badge, surface: *chasen.Surface, opts: ViewOptions) void {
        _ = self;
        const width = surface.size().width;
        if (width == 0) return;

        var cursor: u16 = 0;
        drawSpaces(surface, &cursor, opts.padding_left, opts.padding_style, width);
        drawText(surface, &cursor, opts.marker, opts.marker_style, width);
        if (opts.marker.len > 0 and opts.text.len > 0) {
            drawSpaces(surface, &cursor, opts.gap, opts.padding_style, width);
        }
        drawText(surface, &cursor, opts.text, opts.text_style, width);
        drawSpaces(surface, &cursor, opts.padding_right, opts.padding_style, width);
    }
};

fn drawText(surface: *chasen.Surface, cursor: *u16, text: []const u8, style: chasen.TextStyle, width: u16) void {
    if (text.len == 0 or cursor.* >= width) return;
    _ = surface.borrowTextAt(cursor.*, 0, text, style);
    cursor.* +|= chasen.text.displayWidth(text);
}

fn drawSpaces(surface: *chasen.Surface, cursor: *u16, count: u16, style: chasen.TextStyle, width: u16) void {
    var index: u16 = 0;
    while (index < count and cursor.* < width) : (index += 1) {
        _ = surface.borrowTextAt(cursor.*, 0, " ", style);
        cursor.* +|= 1;
    }
}

test "Badge initializes from options" {
    const badge = Badge.init(.{});
    _ = badge;
}

test "Badge contentWidth includes padding text marker and gap" {
    try std.testing.expectEqual(@as(u16, 8), Badge.contentWidth(.{
        .marker = "!",
        .text = "WARN",
        .gap = 1,
        .padding_left = 1,
        .padding_right = 1,
    }));
}

test "Badge contentWidth omits gap when marker or text is empty" {
    try std.testing.expectEqual(@as(u16, 4), Badge.contentWidth(.{
        .marker = "",
        .text = "OK",
        .gap = 4,
        .padding_left = 1,
        .padding_right = 1,
    }));

    try std.testing.expectEqual(@as(u16, 3), Badge.contentWidth(.{
        .marker = "!",
        .text = "",
        .gap = 4,
        .padding_left = 1,
        .padding_right = 1,
    }));
}

test "Badge contentWidth uses display width" {
    try std.testing.expectEqual(@as(u16, 5), Badge.contentWidth(.{
        .text = "あ",
        .padding_left = 1,
        .padding_right = 2,
    }));
}
