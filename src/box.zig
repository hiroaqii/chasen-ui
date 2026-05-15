const std = @import("std");
const chasen = @import("chasen");
const layout = @import("layout.zig");

/// A small borderless container helper.
///
/// `Box` is display-only and allocation-free. It can fill a rectangular
/// region with styled spaces and calculate an inner content rectangle after
/// padding. It does not own child components, focus, scrolling, or layout
/// policy; applications compose content inside the returned rectangle.
pub const Box = struct {
    /// Initial values used when constructing a `Box`.
    pub const Options = struct {};

    /// Rendering options for `Box.view`.
    pub const ViewOptions = struct {
        /// Surface column where the box should start.
        col: u16 = 0,
        /// Surface row where the box should start.
        row: u16 = 0,
        /// Optional box width.
        ///
        /// When omitted, the box uses the remaining surface width.
        width: ?u16 = null,
        /// Optional box height.
        ///
        /// When omitted, the box uses the remaining surface height.
        height: ?u16 = null,
        /// Padding applied to calculate `contentRect`.
        padding: layout.Insets = .{},
        /// Whether to fill the full box region before app-owned content draws.
        fill: bool = false,
        /// Style used for the filled background cells.
        fill_style: chasen.TextStyle = .{},
    };

    /// Create a box.
    pub fn init(opts: Options) Box {
        _ = opts;
        return .{};
    }

    /// Return the absolute content rectangle inside the box.
    ///
    /// Width and height are resolved the same way as `view`, so omitted
    /// dimensions use the remaining surface area.
    pub fn contentRect(surface: *chasen.Surface, opts: ViewOptions) chasen.Rect {
        return contentRectFor(.{
            .col = opts.col,
            .row = opts.row,
            .width = opts.width orelse availableWidth(surface, opts.col),
            .height = opts.height orelse availableHeight(surface, opts.row),
        }, opts.padding);
    }

    /// Return a content rectangle for an already resolved box rectangle.
    ///
    /// This helper is useful for tests and for apps that calculate box
    /// geometry separately from rendering.
    pub fn contentRectFor(box_rect: chasen.Rect, padding: layout.Insets) chasen.Rect {
        return layout.inset(box_rect, padding);
    }

    /// Fill the box region when requested.
    pub fn view(self: *const Box, surface: *chasen.Surface, opts: ViewOptions) void {
        _ = self;
        const width = opts.width orelse availableWidth(surface, opts.col);
        const height = opts.height orelse availableHeight(surface, opts.row);
        if (width == 0 or height == 0 or !opts.fill) return;

        var child = surface.child(.{
            .col = opts.col,
            .row = opts.row,
            .width = width,
            .height = height,
        });
        child.fillAll(.{
            .char = .{ .grapheme = " ", .width = 1 },
            .style = opts.fill_style.toVaxis(),
        });
    }
};

fn availableWidth(surface: *chasen.Surface, col: u16) u16 {
    const size = surface.size();
    if (col >= size.width) return 0;
    return size.width - col;
}

fn availableHeight(surface: *chasen.Surface, row: u16) u16 {
    const size = surface.size();
    if (row >= size.height) return 0;
    return size.height - row;
}

test "Box initializes from options" {
    const box = Box.init(.{});
    _ = box;
}

test "Box contentRect applies padding" {
    const rect = Box.contentRectFor(.{
        .col = 2,
        .row = 3,
        .width = 20,
        .height = 8,
    }, .{ .top = 1, .right = 2, .bottom = 1, .left = 2 });

    try std.testing.expectEqual(@as(u16, 4), rect.col);
    try std.testing.expectEqual(@as(u16, 4), rect.row);
    try std.testing.expectEqual(@as(u16, 16), rect.width);
    try std.testing.expectEqual(@as(u16, 6), rect.height);
}

test "Box contentRect collapses when padding is larger than the box" {
    const rect = Box.contentRectFor(.{
        .col = 1,
        .row = 1,
        .width = 2,
        .height = 2,
    }, .all(4));

    try std.testing.expectEqual(@as(u16, 3), rect.col);
    try std.testing.expectEqual(@as(u16, 3), rect.row);
    try std.testing.expectEqual(@as(u16, 0), rect.width);
    try std.testing.expectEqual(@as(u16, 0), rect.height);
}
