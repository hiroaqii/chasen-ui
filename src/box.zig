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

    /// Return the app-owned content rectangle inside the provided box surface.
    ///
    /// The returned rectangle is relative to the box surface. Pass it to
    /// `surface.child(rect)` before drawing child content.
    pub fn contentRect(surface: *chasen.Surface, opts: ViewOptions) chasen.Rect {
        return contentRectFor(.{ .col = 0, .row = 0, .width = surface.size().width, .height = surface.size().height }, opts.padding);
    }

    /// Return a content rectangle for an already resolved box rectangle.
    ///
    /// This helper is useful for tests and for apps that calculate box
    /// geometry separately from rendering.
    pub fn contentRectFor(box_rect: chasen.Rect, padding: layout.Insets) chasen.Rect {
        return layout.inset(box_rect, padding);
    }

    /// Fill the provided box surface when requested.
    pub fn view(self: *const Box, surface: *chasen.Surface, opts: ViewOptions) void {
        _ = self;
        if (surface.size().width == 0 or surface.size().height == 0 or !opts.fill) return;

        surface.fillAll(.{
            .char = .{ .grapheme = " ", .width = 1 },
            .style = opts.fill_style.toVaxis(),
        });
    }
};

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
