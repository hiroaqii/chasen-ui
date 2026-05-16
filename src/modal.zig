const std = @import("std");
const chasen = @import("chasen");
const layout = @import("layout.zig");
const box = @import("box.zig");
const panel = @import("panel.zig");

/// A small display-only modal dialog chrome component.
///
/// `Modal` can draw an optional backdrop and a centered bordered dialog. It
/// does not own visibility, dismissal, focus trapping, child components, or
/// overlay stack policy. Applications decide whether the modal is active and
/// render content inside `contentRect`.
pub const Modal = struct {
    /// Initial values used when constructing a `Modal`.
    pub const Options = struct {};

    /// Rendering options for `Modal.view`.
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

    /// Create a modal.
    pub fn init(opts: Options) Modal {
        _ = opts;
        return .{};
    }

    /// Return the overlay rectangle inside the provided modal surface.
    pub fn overlayRect(surface: *chasen.Surface) chasen.Rect {
        return .{ .col = 0, .row = 0, .width = surface.size().width, .height = surface.size().height };
    }

    /// Return the dialog rectangle centered within the provided modal surface.
    ///
    /// The returned rectangle is relative to the modal surface.
    pub fn dialogRect(surface: *chasen.Surface, opts: ViewOptions) chasen.Rect {
        return dialogRectFor(overlayRect(surface), opts);
    }

    /// Return the dialog rectangle for an already resolved overlay rectangle.
    pub fn dialogRectFor(overlay_rect: chasen.Rect, opts: ViewOptions) chasen.Rect {
        return layout.alignRect(overlay_rect, .{
            .width = opts.dialog_width,
            .height = opts.dialog_height,
        }, .middle_center);
    }

    /// Return the content rectangle inside the centered dialog.
    ///
    /// The returned rectangle is relative to the modal surface.
    pub fn contentRect(surface: *chasen.Surface, opts: ViewOptions) chasen.Rect {
        return contentRectFor(dialogRect(surface, opts), opts.padding);
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
        const start = @min(dialog_rect.width - 1, 1 + title_gap);
        if (start >= dialog_rect.width - 1) return 0;
        return dialog_rect.width - 1 - start;
    }

    /// Draw the modal backdrop and dialog chrome into the provided surface.
    pub fn view(self: *const Modal, surface: *chasen.Surface, opts: ViewOptions) void {
        _ = self;
        const overlay = overlayRect(surface);
        if (overlay.width == 0 or overlay.height == 0) return;

        if (opts.backdrop) {
            const backdrop_box = box.Box.init(.{});
            backdrop_box.view(surface, .{
                .fill = true,
                .fill_style = opts.backdrop_style,
            });
        }

        const dialog = dialogRectFor(overlay, opts);
        if (dialog.width == 0 or dialog.height == 0) return;

        const dialog_panel = panel.Panel.init(.{});
        var dialog_surface = surface.child(dialog);
        dialog_panel.view(&dialog_surface, .{
            .title = opts.title,
            .title_gap = opts.title_gap,
            .padding = opts.padding,
            .border = opts.border,
            .border_style = opts.border_style,
            .title_style = opts.title_style,
        });
    }
};

test "Modal initializes from options" {
    const modal = Modal.init(.{});
    _ = modal;
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
