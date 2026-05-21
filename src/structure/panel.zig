const std = @import("std");
const chasen = @import("chasen");
const layout = @import("../layout.zig");

/// A small bordered container component.
///
/// `Panel` is display-only and allocation-free. It draws optional title text
/// and border chrome, then leaves content rendering to the application.
/// `frame` is the preferred app-facing API because it keeps the panel chrome
/// and content surface calculation in one layout context.
pub const Panel = struct {
    /// Border glyphs used by `Panel.view`.
    ///
    /// Glyphs are expected to occupy one terminal cell. Applications can pass
    /// Unicode box-drawing glyphs when the target terminal supports them, or
    /// keep the ASCII defaults for conservative output.
    pub const Border = struct {
        top_left: []const u8 = "+",
        top: []const u8 = "-",
        top_right: []const u8 = "+",
        right: []const u8 = "|",
        bottom_right: []const u8 = "+",
        bottom: []const u8 = "-",
        bottom_left: []const u8 = "+",
        left: []const u8 = "|",

        pub const ascii: Border = .{};
        pub const rounded: Border = .{
            .top_left = "╭",
            .top = "─",
            .top_right = "╮",
            .right = "│",
            .bottom_right = "╯",
            .bottom = "─",
            .bottom_left = "╰",
            .left = "│",
        };
    };

    /// Initial values used when constructing a `Panel`.
    pub const Options = struct {};

    /// Rendering options for `Panel.view`.
    pub const ViewOptions = struct {
        /// Optional title drawn into the top border.
        title: []const u8 = "",
        /// Gap before and after title text when there is room.
        title_gap: u16 = 1,
        /// Padding applied after the border to calculate `contentRect`.
        padding: layout.Insets = .all(1),
        /// Border glyph set.
        border: Border = .ascii,
        /// Style used for border glyphs.
        border_style: chasen.TextStyle = .{ .dim = true },
        /// Style used for the title.
        title_style: chasen.TextStyle = .{ .bold = true },
    };

    /// A resolved panel surface and its rendering options.
    ///
    /// `Frame` does not own children, focus, or scrolling. It only keeps the
    /// outer panel surface and options together so callers can draw the chrome
    /// and then derive the matching clipped content surface without repeating
    /// border/padding arithmetic.
    pub const Frame = struct {
        surface: *chasen.Surface,
        opts: ViewOptions,

        /// Draw the panel chrome into the frame surface.
        pub fn view(self: *const Frame) void {
            Panel.init(.{}).view(self.surface, self.opts);
        }

        /// Return the frame-local content rectangle after border and padding.
        pub fn contentRect(self: *const Frame) chasen.Rect {
            const size = self.surface.size();
            return Panel.contentRectFor(.{
                .col = 0,
                .row = 0,
                .width = size.width,
                .height = size.height,
            }, self.opts.padding);
        }

        /// Return a clipped surface for child content inside this panel.
        ///
        /// Prefer this over manually combining `Panel.contentRectFor` and
        /// `Surface.child` in app code. It guarantees the same surface/options
        /// context is used for the border and the content region.
        pub fn contentSurface(self: *const Frame) chasen.Surface {
            return self.surface.child(self.contentRect());
        }

        /// Return the size of the content surface without constructing it.
        pub fn contentSize(self: *const Frame) chasen.Size {
            const rect = self.contentRect();
            return .{ .width = rect.width, .height = rect.height };
        }
    };

    /// Create a panel.
    pub fn init(opts: Options) Panel {
        _ = opts;
        return .{};
    }

    /// Resolve a panel frame for the provided surface and options.
    ///
    /// Use `frame.view()` to draw the border/title and
    /// `frame.contentSurface()` to draw app-owned child content.
    pub fn frame(surface: *chasen.Surface, opts: ViewOptions) Frame {
        return .{ .surface = surface, .opts = opts };
    }

    /// Return a content rectangle for an already resolved panel rectangle.
    ///
    /// This helper is useful for tests and for apps that calculate panel
    /// geometry separately from rendering.
    pub fn contentRectFor(panel_rect: chasen.Rect, padding: layout.Insets) chasen.Rect {
        const inner = chasen.Rect{
            .col = panel_rect.col +| @min(panel_rect.width, 1),
            .row = panel_rect.row +| @min(panel_rect.height, 1),
            .width = panel_rect.width -| @min(panel_rect.width, 2),
            .height = panel_rect.height -| @min(panel_rect.height, 2),
        };
        return layout.inset(inner, padding);
    }

    /// Draw panel border and title into the provided surface.
    pub fn view(self: *const Panel, surface: *chasen.Surface, opts: ViewOptions) void {
        _ = self;
        const size = surface.size();
        const width = size.width;
        const height = size.height;
        if (width == 0 or height == 0) return;

        drawHorizontal(surface, 0, width, opts.border.top, opts.border_style);
        if (height > 1) {
            drawHorizontal(surface, height - 1, width, opts.border.bottom, opts.border_style);
        }

        drawText(surface, 0, 0, opts.border.top_left, opts.border_style);
        if (width > 1) {
            drawText(surface, width - 1, 0, opts.border.top_right, opts.border_style);
        }
        if (height > 1) {
            drawText(surface, 0, height - 1, opts.border.bottom_left, opts.border_style);
            if (width > 1) {
                drawText(surface, width - 1, height - 1, opts.border.bottom_right, opts.border_style);
            }
        }

        if (height > 2) {
            var row: u16 = 1;
            while (row < height - 1) : (row += 1) {
                drawText(surface, 0, row, opts.border.left, opts.border_style);
                if (width > 1) {
                    drawText(surface, width - 1, row, opts.border.right, opts.border_style);
                }
            }
        }

        drawTitle(surface, width, opts);
    }
};

fn drawHorizontal(surface: *chasen.Surface, row: u16, width: u16, glyph: []const u8, style: chasen.TextStyle) void {
    var col: u16 = 0;
    while (col < width) : (col += 1) {
        drawText(surface, col, row, glyph, style);
    }
}

fn drawTitle(surface: *chasen.Surface, width: u16, opts: Panel.ViewOptions) void {
    if (opts.title.len == 0 or width <= 2) return;

    const start = @min(width - 1, 1 + opts.title_gap);
    if (start >= width - 1) return;

    const max_width = width - 1 - start;
    if (opts.title_gap > 0 and start > 1) {
        drawText(surface, start - 1, 0, " ", opts.title_style);
    }

    var title_surface = surface.child(.{
        .col = start,
        .row = 0,
        .width = max_width,
        .height = 1,
    });
    _ = title_surface.borrowTextAt(0, 0, opts.title, opts.title_style);

    const title_width = @min(chasen.text.displayWidth(opts.title), max_width);
    const after_title = start + title_width;
    if (opts.title_gap > 0 and after_title < width - 1) {
        drawText(surface, after_title, 0, " ", opts.title_style);
    }
}

fn drawText(surface: *chasen.Surface, col: u16, row: u16, text: []const u8, style: chasen.TextStyle) void {
    _ = surface.borrowTextAt(col, row, text, style);
}

test "Panel initializes from options" {
    const panel = Panel.init(.{});
    _ = panel;
}

test "Panel contentRect removes border and padding" {
    const rect = Panel.contentRectFor(.{
        .col = 2,
        .row = 3,
        .width = 20,
        .height = 8,
    }, .{ .top = 1, .right = 2, .bottom = 1, .left = 2 });

    try std.testing.expectEqual(@as(u16, 5), rect.col);
    try std.testing.expectEqual(@as(u16, 5), rect.row);
    try std.testing.expectEqual(@as(u16, 14), rect.width);
    try std.testing.expectEqual(@as(u16, 4), rect.height);
}

test "Panel contentRect collapses when panel is too small" {
    const rect = Panel.contentRectFor(.{
        .width = 1,
        .height = 1,
        .col = 0,
        .row = 0,
    }, .all(2));

    try std.testing.expectEqual(@as(u16, 1), rect.col);
    try std.testing.expectEqual(@as(u16, 1), rect.row);
    try std.testing.expectEqual(@as(u16, 0), rect.width);
    try std.testing.expectEqual(@as(u16, 0), rect.height);
}

test "Panel frame content surface matches content rect" {
    var ts: chasen.testing.TestSurface = undefined;
    try ts.init(20, 8);
    defer ts.deinit();

    var surface = ts.surface;
    const frame = Panel.frame(&surface, .{
        .padding = .{ .top = 1, .right = 2, .bottom = 1, .left = 2 },
    });

    const rect = frame.contentRect();
    const content = frame.contentSize();
    var child = frame.contentSurface();
    const child_size = child.size();

    try std.testing.expectEqual(@as(u16, 3), rect.col);
    try std.testing.expectEqual(@as(u16, 2), rect.row);
    try std.testing.expectEqual(@as(u16, 14), rect.width);
    try std.testing.expectEqual(@as(u16, 4), rect.height);
    try std.testing.expectEqual(content, child_size);
}
