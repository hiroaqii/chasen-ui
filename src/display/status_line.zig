const std = @import("std");
const chasen = @import("chasen");
const layout = @import("../layout.zig");

/// A small one-line status component with left, center, and right text slots.
///
/// `StatusLine` is display-only and allocation-free. It borrows all text and
/// draws a single clipped row. Applications own the meaning of each slot, such
/// as current mode, active file, help hint, or progress summary.
pub const StatusLine = struct {
    /// Text drawn from the left edge of the status line.
    left: []const u8 = "",
    /// Text centered within the status line width.
    center: []const u8 = "",
    /// Text right-aligned within the status line width.
    right: []const u8 = "",

    /// Initial values used when constructing a `StatusLine`.
    pub const Options = struct {
        /// Text borrowed by the component for its lifetime.
        left: []const u8 = "",
        /// Text borrowed by the component for its lifetime.
        center: []const u8 = "",
        /// Text borrowed by the component for its lifetime.
        right: []const u8 = "",
    };

    /// Rendering options for `StatusLine.view`.
    pub const ViewOptions = struct {
        /// Style used for status text.
        style: chasen.TextStyle = .{ .dim = true },
        /// Whether to paint the full status region with spaces before text.
        fill: bool = true,
        /// Style used for the filled background cells.
        fill_style: chasen.TextStyle = .{ .dim = true },
    };

    /// Create a status line.
    pub fn init(opts: Options) StatusLine {
        return .{
            .left = opts.left,
            .center = opts.center,
            .right = opts.right,
        };
    }

    /// Return the start column for right-aligned text within `width`.
    pub fn rightCol(text: []const u8, width: u16) u16 {
        return layout.horizontalOffset(width, chasen.text.displayWidth(text), .right);
    }

    /// Return the start column for centered text within `width`.
    pub fn centerCol(text: []const u8, width: u16) u16 {
        return layout.horizontalOffset(width, chasen.text.displayWidth(text), .center);
    }

    /// Draw the status line into the provided one-line surface region.
    pub fn view(self: *const StatusLine, surface: *chasen.Surface, opts: ViewOptions) void {
        const width = surface.size().width;
        if (width == 0) return;

        if (opts.fill) {
            fillLine(surface, width, opts.fill_style);
        }

        // Draw left, center, then right. When a narrow width causes overlap,
        // later slots overwrite earlier slots. This keeps the right hint or
        // summary visible, which is usually the most compact status item.
        _ = surface.borrowTextAt(0, 0, self.left, opts.style);
        _ = surface.borrowTextAt(centerCol(self.center, width), 0, self.center, opts.style);
        _ = surface.borrowTextAt(rightCol(self.right, width), 0, self.right, opts.style);
    }
};

fn fillLine(surface: *chasen.Surface, width: u16, style: chasen.TextStyle) void {
    var col: u16 = 0;
    while (col < width) : (col += 1) {
        _ = surface.borrowTextAt(col, 0, " ", style);
    }
}

test "StatusLine initializes from options" {
    const status = StatusLine.init(.{
        .left = "NORMAL",
        .center = "main.zig",
        .right = "Esc: quit",
    });

    try std.testing.expectEqualStrings("NORMAL", status.left);
    try std.testing.expectEqualStrings("main.zig", status.center);
    try std.testing.expectEqualStrings("Esc: quit", status.right);
}

test "StatusLine rightCol aligns text to the right edge" {
    try std.testing.expectEqual(@as(u16, 7), StatusLine.rightCol("abc", 10));
    try std.testing.expectEqual(@as(u16, 0), StatusLine.rightCol("abcdefghij", 10));
    try std.testing.expectEqual(@as(u16, 0), StatusLine.rightCol("abcdefghijk", 10));
}

test "StatusLine centerCol centers text within width" {
    try std.testing.expectEqual(@as(u16, 3), StatusLine.centerCol("abcd", 10));
    try std.testing.expectEqual(@as(u16, 4), StatusLine.centerCol("ab", 10));
    try std.testing.expectEqual(@as(u16, 0), StatusLine.centerCol("abcdefghij", 10));
}

test "StatusLine alignment helpers use display width" {
    try std.testing.expectEqual(@as(u16, 6), StatusLine.rightCol("あい", 10));
    try std.testing.expectEqual(@as(u16, 3), StatusLine.centerCol("あい", 10));
}
