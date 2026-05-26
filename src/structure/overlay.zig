const std = @import("std");
const chasen = @import("chasen");
const layout = @import("../layout.zig");
const panel = @import("panel.zig");

/// A lightweight framed overlay region.
///
/// `Overlay` is display-only and allocation-free. It resolves a front-most
/// rectangle inside a parent surface, optionally clears that rectangle, draws
/// `Panel` chrome, and returns a matching content surface for app-owned
/// rendering.
///
/// It does not own visibility, dismissal, focus trapping, keyboard routing,
/// overlay stacking, or child content. Applications keep those policies.
pub const Overlay = struct {
    /// Initial values used when constructing an `Overlay`.
    pub const Options = struct {};

    /// Placement policy for the resolved overlay rectangle.
    pub const Placement = enum {
        /// Center the overlay inside the parent surface.
        center,
    };

    /// Rendering options for `Overlay.frame`.
    pub const ViewOptions = struct {
        /// Requested overlay size. The resolved rectangle is clamped to the
        /// parent surface, matching `layout.alignRect` behavior.
        size: chasen.Size = .{ .width = 30, .height = 10 },
        /// Placement inside the parent surface.
        placement: Placement = .center,
        /// Whether `Frame.view` clears the resolved overlay rectangle before
        /// drawing panel chrome. This clears only the overlay rectangle; it is
        /// not a modal backdrop or dimming policy.
        clear_background: bool = true,
        /// Panel chrome drawn inside the resolved overlay rectangle.
        panel: panel.Panel.ViewOptions = .{},
    };

    /// A resolved overlay frame.
    ///
    /// The frame keeps parent surface, resolved rectangle, and rendering
    /// options together so callers can draw chrome and then derive matching
    /// content surfaces without repeating placement or panel arithmetic.
    pub const Frame = struct {
        surface: *chasen.Surface,
        rect_value: chasen.Rect,
        opts: ViewOptions,

        /// Draw the overlay clear region and panel chrome.
        pub fn view(self: *const Frame) void {
            if (self.opts.clear_background) {
                self.surface.clear(self.rect_value);
            }
            var overlay_surface = self.surface.child(self.rect_value);
            const panel_frame = panel.Panel.frame(&overlay_surface, self.opts.panel);
            panel_frame.view();
        }

        /// Return the resolved overlay rectangle relative to the parent
        /// surface.
        pub fn rect(self: *const Frame) chasen.Rect {
            return self.rect_value;
        }

        /// Return the content rectangle relative to the parent surface.
        pub fn contentRect(self: *const Frame) chasen.Rect {
            return panel.Panel.contentRectFor(self.rect_value, self.opts.panel.padding);
        }

        /// Return a clipped surface for app-owned content inside the overlay.
        pub fn contentSurface(self: *const Frame) chasen.Surface {
            return self.surface.child(self.contentRect());
        }

        /// Return the size of the content surface without constructing it.
        pub fn contentSize(self: *const Frame) chasen.Size {
            const rect_value = self.contentRect();
            return .{ .width = rect_value.width, .height = rect_value.height };
        }
    };

    /// Create an overlay.
    pub fn init(opts: Options) Overlay {
        _ = opts;
        return .{};
    }

    /// Resolve an overlay frame for the provided parent surface and options.
    ///
    /// Requested size is clamped to the parent surface. `null` is returned only
    /// when no drawable overlay rectangle or content surface can be produced.
    pub fn frame(surface: *chasen.Surface, opts: ViewOptions) ?Frame {
        const rect_value = rect(surface, opts) orelse return null;
        const content = panel.Panel.contentRectFor(rect_value, opts.panel.padding);
        if (content.width == 0 or content.height == 0) {
            return null;
        }
        return .{
            .surface = surface,
            .rect_value = rect_value,
            .opts = opts,
        };
    }

    /// Return the resolved overlay rectangle relative to the parent surface.
    pub fn rect(surface: *chasen.Surface, opts: ViewOptions) ?chasen.Rect {
        const size = surface.size();
        if (size.width == 0 or size.height == 0) return null;

        const parent = chasen.Rect{ .col = 0, .row = 0, .width = size.width, .height = size.height };
        const rect_value = switch (opts.placement) {
            .center => layout.center(parent, opts.size),
        };
        if (rect_value.width == 0 or rect_value.height == 0) return null;
        return rect_value;
    }
};

test "Overlay initializes from options" {
    const overlay = Overlay.init(.{});
    _ = overlay;
}

test "Overlay rect centers and clamps requested size" {
    var ts: chasen.testing.TestSurface = undefined;
    try ts.init(20, 8);
    defer ts.deinit();

    var surface = ts.surface;
    const centered = Overlay.rect(&surface, .{ .size = .{ .width = 10, .height = 4 } }).?;

    try std.testing.expectEqual(@as(u16, 5), centered.col);
    try std.testing.expectEqual(@as(u16, 2), centered.row);
    try std.testing.expectEqual(@as(u16, 10), centered.width);
    try std.testing.expectEqual(@as(u16, 4), centered.height);

    const clamped = Overlay.rect(&surface, .{ .size = .{ .width = 99, .height = 99 } }).?;

    try std.testing.expectEqual(@as(u16, 0), clamped.col);
    try std.testing.expectEqual(@as(u16, 0), clamped.row);
    try std.testing.expectEqual(@as(u16, 20), clamped.width);
    try std.testing.expectEqual(@as(u16, 8), clamped.height);
}

test "Overlay frame exposes parent-relative content rect" {
    var ts: chasen.testing.TestSurface = undefined;
    try ts.init(20, 8);
    defer ts.deinit();

    var surface = ts.surface;
    const frame_value = Overlay.frame(&surface, .{
        .size = .{ .width = 10, .height = 6 },
        .panel = .{ .padding = .{ .top = 1, .right = 2, .bottom = 1, .left = 2 } },
    }).?;

    const rect_value = frame_value.rect();
    const content = frame_value.contentRect();
    const content_size = frame_value.contentSize();
    var child = frame_value.contentSurface();

    try std.testing.expectEqual(@as(u16, 5), rect_value.col);
    try std.testing.expectEqual(@as(u16, 1), rect_value.row);
    try std.testing.expectEqual(@as(u16, 8), content.col);
    try std.testing.expectEqual(@as(u16, 3), content.row);
    try std.testing.expectEqual(@as(u16, 4), content.width);
    try std.testing.expectEqual(@as(u16, 2), content.height);
    try std.testing.expectEqual(content_size, child.size());
}

test "Overlay frame clears and draws panel chrome" {
    var ts: chasen.testing.TestSurface = undefined;
    try ts.init(12, 6);
    defer ts.deinit();

    var surface = ts.surface;
    _ = surface.borrowTextAt(0, 0, "background", .{});

    const frame_value = Overlay.frame(&surface, .{
        .size = .{ .width = 8, .height = 6 },
        .panel = .{ .title = "O" },
    }).?;
    frame_value.view();

    try ts.expectCellText(2, 0, "+");
    try ts.expectCellText(3, 0, " ");
    try ts.expectCellText(4, 0, "O");
}
