const std = @import("std");
const chasen = @import("chasen");

/// A one-line breadcrumb trail component.
///
/// `Breadcrumbs` is display-only and allocation-free. It borrows path segment
/// labels and draws them with a separator. Applications decide what each
/// segment means, how navigation works, and what the current segment controls.
pub const Breadcrumbs = struct {
    /// Path segment labels borrowed by the component.
    items: []const []const u8 = &.{},

    /// Initial values used when constructing `Breadcrumbs`.
    pub const Options = struct {
        /// Path segment labels borrowed by the component for its lifetime.
        items: []const []const u8 = &.{},
    };

    /// Rendering options for `Breadcrumbs.view`.
    pub const ViewOptions = struct {
        /// Surface column where the breadcrumb trail should be drawn.
        col: u16 = 0,
        /// Surface row where the breadcrumb trail should be drawn.
        row: u16 = 0,
        /// Optional width of the clipped one-line breadcrumb region.
        width: ?u16 = null,
        /// Separator drawn between segment labels.
        separator: []const u8 = " / ",
        /// Style used for non-current segment labels.
        item_style: chasen.TextStyle = .{ .dim = true },
        /// Style used for the current segment label.
        current_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for separators.
        separator_style: chasen.TextStyle = .{ .dim = true },
        /// Label shown when there are no breadcrumb segments.
        empty_label: []const u8 = "(root)",
        /// Style used for `empty_label`.
        empty_style: chasen.TextStyle = .{ .dim = true },
    };

    /// Create a breadcrumb trail.
    pub fn init(opts: Options) Breadcrumbs {
        return .{ .items = opts.items };
    }

    /// Return whether the trail has no segments.
    pub fn empty(self: *const Breadcrumbs) bool {
        return self.items.len == 0;
    }

    /// Return the current segment index.
    ///
    /// When the trail is empty, this returns `0`.
    pub fn currentIndex(self: *const Breadcrumbs) usize {
        if (self.empty()) return 0;
        return self.items.len - 1;
    }

    /// Return the current segment label, or null when the trail is empty.
    pub fn currentLabel(self: *const Breadcrumbs) ?[]const u8 {
        if (self.empty()) return null;
        return self.items[self.currentIndex()];
    }

    /// Return the display width the full trail would occupy.
    pub fn displayWidth(self: *const Breadcrumbs, separator: []const u8) u16 {
        if (self.empty()) return 0;

        var width: u16 = 0;
        for (self.items, 0..) |item, index| {
            if (index > 0) width +|= chasen.text.displayWidth(separator);
            width +|= chasen.text.displayWidth(item);
        }
        return width;
    }

    /// Draw the breadcrumb trail into a one-line region.
    pub fn view(self: *const Breadcrumbs, surface: *chasen.Surface, opts: ViewOptions) void {
        const width = opts.width orelse availableWidth(surface, opts.col);
        if (width == 0) return;

        var child = surface.child(.{
            .col = opts.col,
            .row = opts.row,
            .width = width,
            .height = 1,
        });

        if (self.empty()) {
            _ = child.textAt(0, 0, opts.empty_label, opts.empty_style);
            return;
        }

        var col: u16 = 0;
        for (self.items, 0..) |item, index| {
            if (index > 0) {
                if (!drawText(&child, &col, width, opts.separator, opts.separator_style)) break;
            }

            const style = if (index == self.currentIndex()) opts.current_style else opts.item_style;
            if (!drawText(&child, &col, width, item, style)) break;
        }
    }
};

fn drawText(surface: *chasen.Surface, col: *u16, width: u16, text: []const u8, style: chasen.TextStyle) bool {
    if (col.* >= width) return false;

    const text_width = chasen.text.displayWidth(text);
    if (text_width > width - col.*) return false;

    _ = surface.textAt(col.*, 0, text, style);
    col.* += text_width;
    return true;
}

fn availableWidth(surface: *chasen.Surface, col: u16) u16 {
    const size = surface.size();
    if (col >= size.width) return 0;
    return size.width - col;
}

test "Breadcrumbs initializes with borrowed items" {
    const items = [_][]const u8{ "Home", "Projects", "Chasen" };
    const breadcrumbs = Breadcrumbs.init(.{ .items = &items });

    try std.testing.expectEqual(@as(usize, 3), breadcrumbs.items.len);
    try std.testing.expectEqual(@as(usize, 2), breadcrumbs.currentIndex());
    try std.testing.expectEqualStrings("Chasen", breadcrumbs.currentLabel().?);
    try std.testing.expect(!breadcrumbs.empty());
}

test "Breadcrumbs handles empty items" {
    const breadcrumbs = Breadcrumbs.init(.{});

    try std.testing.expect(breadcrumbs.empty());
    try std.testing.expectEqual(@as(usize, 0), breadcrumbs.currentIndex());
    try std.testing.expect(breadcrumbs.currentLabel() == null);
}

test "Breadcrumbs displayWidth includes separators" {
    const items = [_][]const u8{ "Home", "Projects", "Chasen" };
    const breadcrumbs = Breadcrumbs.init(.{ .items = &items });

    try std.testing.expectEqual(@as(u16, 24), breadcrumbs.displayWidth(" / "));
}

test "Breadcrumbs displayWidth uses display width" {
    const items = [_][]const u8{ "ホーム", "設定" };
    const breadcrumbs = Breadcrumbs.init(.{ .items = &items });

    try std.testing.expectEqual(@as(u16, 13), breadcrumbs.displayWidth(" / "));
}

test "Breadcrumbs displayWidth saturates for oversized trails" {
    const long = "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz";
    const items = [_][]const u8{long} ** 1000;
    const breadcrumbs = Breadcrumbs.init(.{ .items = &items });

    try std.testing.expectEqual(std.math.maxInt(u16), breadcrumbs.displayWidth(" / "));
}
