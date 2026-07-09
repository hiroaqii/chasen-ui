const std = @import("std");
const chasen = @import("chasen");
const layout = @import("../layout.zig");
const panel = @import("panel.zig");

/// A small display-only modal dialog chrome component.
///
/// `Modal` can draw an optional backdrop and a centered bordered dialog. It
/// does not own visibility, dismissal, focus trapping, child components, or
/// overlay stack policy. Applications decide whether the modal is active and
/// render content inside `Frame.contentSurface()`.
pub const Modal = struct {
    /// Rendering options for `Modal.frame`.
    pub const ViewOptions = struct {
        /// Requested dialog width, clamped to the overlay region.
        dialog_width: u16 = 48,
        /// Requested dialog height, clamped to the overlay region.
        dialog_height: u16 = 10,
        /// Optional title drawn into the dialog top border.
        title: []const u8 = "",
        /// Gap before and after title text when there is room.
        title_gap: u16 = 1,
        /// Padding applied after the dialog border to calculate `contentRect`.
        padding: layout.Insets = .all(1),
        /// Whether to fill the overlay region before drawing the dialog.
        backdrop: bool = true,
        /// Style used for backdrop fill cells.
        backdrop_style: chasen.TextStyle = .{ .dim = true },
        /// Border glyph set used by the dialog panel.
        border: panel.Panel.Border = .ascii,
        /// Style used for dialog border glyphs.
        border_style: chasen.TextStyle = .{ .dim = true },
        /// Style used for the dialog title.
        title_style: chasen.TextStyle = .{ .bold = true },
    };

    /// A resolved modal frame.
    ///
    /// The frame keeps surface, resolved geometry, and rendering options
    /// together so callers can draw the modal chrome and then derive matching
    /// dialog/content surfaces without repeating centering or padding math.
    pub const Frame = struct {
        surface: *chasen.Surface,
        overlay_rect: chasen.Rect,
        dialog_rect: chasen.Rect,
        opts: ViewOptions,

        /// Draw the optional backdrop and dialog chrome.
        pub fn view(self: *const Frame) void {
            if (self.opts.backdrop) {
                var overlay_surface = self.surface.child(self.overlay_rect);
                overlay_surface.fillAll(.{
                    .char = .{ .grapheme = " ", .width = 1 },
                    .style = self.opts.backdrop_style,
                });
            }

            var dialog_surface = self.dialogSurface();
            const dialog_panel = panel.Panel.frame(&dialog_surface, .{
                .title = self.opts.title,
                .title_gap = self.opts.title_gap,
                .padding = self.opts.padding,
                .border = self.opts.border,
                .border_style = self.opts.border_style,
                .title_style = self.opts.title_style,
            });
            dialog_panel.view();
        }

        /// Return the full modal overlay rectangle relative to the modal surface.
        pub fn overlayRect(self: *const Frame) chasen.Rect {
            return self.overlay_rect;
        }

        /// Return the dialog rectangle relative to the modal surface.
        pub fn dialogRect(self: *const Frame) chasen.Rect {
            return self.dialog_rect;
        }

        /// Return a clipped surface for the full dialog.
        ///
        /// This is useful when app code needs to make the dialog area opaque
        /// before drawing chrome and content.
        pub fn dialogSurface(self: *const Frame) chasen.Surface {
            return self.surface.child(self.dialog_rect);
        }

        /// Return the content rectangle relative to the modal surface.
        pub fn contentRect(self: *const Frame) chasen.Rect {
            return Modal.contentRectFor(self.dialog_rect, self.opts.padding);
        }

        /// Return a clipped surface for app-owned content inside the dialog.
        pub fn contentSurface(self: *const Frame) chasen.Surface {
            return self.surface.child(self.contentRect());
        }

        /// Return the size of the content surface without constructing it.
        pub fn contentSize(self: *const Frame) chasen.Size {
            return rectSize(self.contentRect());
        }
    };

    /// Resolve a modal frame for the provided surface and options.
    ///
    /// `null` is returned when no drawable content surface can be produced.
    pub fn frame(surface: *chasen.Surface, opts: ViewOptions) ?Frame {
        const size = surface.size();
        if (size.width == 0 or size.height == 0) return null;

        const overlay_rect = chasen.Rect{ .col = 0, .row = 0, .width = size.width, .height = size.height };
        const dialog_rect = dialogRectFor(overlay_rect, opts);
        if (dialog_rect.width == 0 or dialog_rect.height == 0) return null;

        const content_rect = contentRectFor(dialog_rect, opts.padding);
        if (content_rect.width == 0 or content_rect.height == 0) return null;

        return .{
            .surface = surface,
            .overlay_rect = overlay_rect,
            .dialog_rect = dialog_rect,
            .opts = opts,
        };
    }

    /// Return the dialog rectangle for an already resolved overlay rectangle.
    pub fn dialogRectFor(overlay_rect: chasen.Rect, opts: ViewOptions) chasen.Rect {
        return layout.alignRect(overlay_rect, .{
            .width = opts.dialog_width,
            .height = opts.dialog_height,
        }, .middle_center);
    }

    /// Return a content rectangle for an already resolved dialog rectangle.
    pub fn contentRectFor(dialog_rect: chasen.Rect, padding: layout.Insets) chasen.Rect {
        return panel.Panel.contentRectFor(dialog_rect, padding);
    }

    /// Return the maximum title text width available inside the dialog border.
    ///
    /// This mirrors the title clipping constraint enforced by `Panel`, which
    /// `Modal` uses for dialog chrome. Width `0` means the dialog is too narrow
    /// to draw title text without touching the right border.
    pub fn titleMaxWidthFor(dialog_rect: chasen.Rect, title_gap: u16) u16 {
        if (dialog_rect.width <= 2) return 0;
        const start = @min(dialog_rect.width - 1, @as(u16, 1) +| title_gap);
        if (start >= dialog_rect.width - 1) return 0;
        return dialog_rect.width - 1 - start;
    }
};

fn rectSize(rect: chasen.Rect) chasen.Size {
    return .{ .width = rect.width, .height = rect.height };
}

test "Modal dialogRectFor centers and clamps dialog" {
    const rect = Modal.dialogRectFor(.{
        .col = 2,
        .row = 1,
        .width = 40,
        .height = 12,
    }, .{
        .dialog_width = 20,
        .dialog_height = 6,
    });

    try std.testing.expectEqual(@as(u16, 12), rect.col);
    try std.testing.expectEqual(@as(u16, 4), rect.row);
    try std.testing.expectEqual(@as(u16, 20), rect.width);
    try std.testing.expectEqual(@as(u16, 6), rect.height);
}

test "Modal dialogRectFor clamps oversized dialog to overlay" {
    const rect = Modal.dialogRectFor(.{
        .col = 3,
        .row = 4,
        .width = 8,
        .height = 5,
    }, .{
        .dialog_width = 20,
        .dialog_height = 10,
    });

    try std.testing.expectEqual(@as(u16, 3), rect.col);
    try std.testing.expectEqual(@as(u16, 4), rect.row);
    try std.testing.expectEqual(@as(u16, 8), rect.width);
    try std.testing.expectEqual(@as(u16, 5), rect.height);
}

test "Modal contentRectFor removes dialog border and padding" {
    const rect = Modal.contentRectFor(.{
        .col = 10,
        .row = 5,
        .width = 24,
        .height = 8,
    }, .{ .top = 1, .right = 2, .bottom = 1, .left = 2 });

    try std.testing.expectEqual(@as(u16, 13), rect.col);
    try std.testing.expectEqual(@as(u16, 7), rect.row);
    try std.testing.expectEqual(@as(u16, 18), rect.width);
    try std.testing.expectEqual(@as(u16, 4), rect.height);
}

test "Modal contentRectFor dimensions can be used as content size" {
    const dialog_rect = chasen.Rect{
        .col = 10,
        .row = 5,
        .width = 24,
        .height = 8,
    };
    const padding = layout.Insets{ .top = 1, .right = 2, .bottom = 1, .left = 2 };

    const rect = Modal.contentRectFor(dialog_rect, padding);
    const size = rectSize(rect);

    try std.testing.expectEqual(rect.width, size.width);
    try std.testing.expectEqual(rect.height, size.height);
}

test "Modal titleMaxWidthFor handles maximum title gap" {
    const width = Modal.titleMaxWidthFor(.{
        .col = 0,
        .row = 0,
        .width = 8,
        .height = 4,
    }, std.math.maxInt(u16));

    try std.testing.expectEqual(@as(u16, 0), width);
}

test "Modal frame contentRect matches pure geometry helpers" {
    var ts: chasen.testing.TestSurface = undefined;
    try ts.init(30, 12);
    defer ts.deinit();

    const opts = Modal.ViewOptions{
        .dialog_width = 20,
        .dialog_height = 8,
        .padding = .{ .top = 1, .right = 2, .bottom = 1, .left = 2 },
    };

    const frame = Modal.frame(&ts.surface, opts).?;
    const expected_dialog = Modal.dialogRectFor(frame.overlayRect(), opts);
    const expected_content = Modal.contentRectFor(expected_dialog, opts.padding);

    try std.testing.expectEqual(expected_dialog, frame.dialogRect());
    try std.testing.expectEqual(expected_content, frame.contentRect());
    try std.testing.expectEqual(rectSize(expected_content), frame.contentSize());
}

test "Modal frame exposes dialog and content surfaces" {
    var ts: chasen.testing.TestSurface = undefined;
    try ts.init(30, 12);
    defer ts.deinit();

    const frame_value = Modal.frame(&ts.surface, .{
        .dialog_width = 20,
        .dialog_height = 8,
        .padding = .{ .top = 1, .right = 2, .bottom = 1, .left = 2 },
    }).?;
    var dialog = frame_value.dialogSurface();
    var content = frame_value.contentSurface();

    try std.testing.expectEqual(frame_value.dialogRect().width, dialog.size().width);
    try std.testing.expectEqual(frame_value.dialogRect().height, dialog.size().height);
    try std.testing.expectEqual(frame_value.contentSize(), content.size());
}

test "Modal frame returns null for zero overlay or content" {
    var zero: chasen.testing.TestSurface = undefined;
    try zero.init(0, 4);
    defer zero.deinit();

    try std.testing.expect(Modal.frame(&zero.surface, .{}) == null);

    var tiny: chasen.testing.TestSurface = undefined;
    try tiny.init(2, 2);
    defer tiny.deinit();

    try std.testing.expect(Modal.frame(&tiny.surface, .{
        .dialog_width = 2,
        .dialog_height = 2,
        .padding = .all(4),
    }) == null);
}

test "Modal frame view fills backdrop and draws dialog chrome" {
    var ts: chasen.testing.TestSurface = undefined;
    try ts.init(12, 6);
    defer ts.deinit();

    const frame_value = Modal.frame(&ts.surface, .{
        .dialog_width = 8,
        .dialog_height = 5,
        .title = "M",
        .backdrop = true,
        .backdrop_style = .{ .fg = .gray },
    }).?;
    frame_value.view();

    try ts.expectCellText(0, 0, " ");
    try ts.expectCellText(2, 0, "+");
    try ts.expectCellText(4, 0, "M");
    try std.testing.expect(ts.surface.readCell(0, 0).?.style.fg.eql(.gray));
}

test "Modal titleMaxWidthFor keeps title text before right border" {
    try std.testing.expectEqual(@as(u16, 6), Modal.titleMaxWidthFor(.{
        .col = 0,
        .row = 0,
        .width = 10,
        .height = 4,
    }, 2));

    try std.testing.expectEqual(@as(u16, 0), Modal.titleMaxWidthFor(.{
        .col = 0,
        .row = 0,
        .width = 2,
        .height = 4,
    }, 1));
}
