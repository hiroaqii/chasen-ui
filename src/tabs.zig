const std = @import("std");
const chasen = @import("chasen");
const FocusList = @import("focus_list.zig").FocusList;
const selectable = @import("selectable.zig");

/// A one-line tab strip with local focus and active tab state.
///
/// `Tabs` borrows tab labels. It owns which tab is focused and which tab is
/// active, while applications decide what each active tab means and which panel
/// content to render below the tab strip.
pub const Tabs = struct {
    /// Tab labels borrowed by the component.
    items: []const []const u8 = &.{},
    /// Local focus state for the tab labels.
    focus: FocusList = .{},
    /// Currently active tab index.
    active_index: usize = 0,

    /// Initial values used when constructing `Tabs`.
    pub const Options = struct {
        /// Tab labels borrowed by the component for its lifetime.
        items: []const []const u8 = &.{},
        /// Initial active tab index. Values outside `items` are clamped.
        active_index: usize = 0,
    };

    /// Messages understood by `Tabs.update`.
    pub const Msg = union(enum) {
        /// Move focus to the previous tab.
        move_prev,
        /// Move focus to the next tab.
        move_next,
        /// Set the active tab index explicitly. Values outside `items` are clamped.
        set_active: usize,
        /// Activate the currently focused tab.
        activate: usize,
    };

    /// Rendering options for `Tabs.view`.
    pub const ViewOptions = struct {
        /// Gap between rendered tabs.
        gap: u16 = 1,
        /// Style used for inactive, unfocused tab labels.
        item_style: chasen.TextStyle = .{},
        /// Style used for focused inactive tab labels.
        focused_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for active tab labels.
        active_style: chasen.TextStyle = .{ .fg = .{ .index = 2 } },
        /// Style used for focused active tab labels.
        focused_active_style: chasen.TextStyle = .{ .bold = true, .fg = .{ .index = 2 } },
        /// Style used for tab boundary markers.
        marker_style: chasen.TextStyle = .{ .dim = true },
        /// Marker drawn before each tab label.
        ///
        /// The initial Tabs layout assumes this occupies one display cell.
        left_marker: []const u8 = "[",
        /// Marker drawn after each tab label.
        ///
        /// The initial Tabs layout assumes this occupies one display cell.
        right_marker: []const u8 = "]",
        /// Label shown when there are no tabs.
        empty_label: []const u8 = "(empty)",
        /// Style used for `empty_label`.
        empty_style: chasen.TextStyle = .{ .dim = true },
        /// Whether `view` should place the terminal cursor on the focused tab.
        show_cursor: bool = true,
    };

    /// Create a tab strip.
    pub fn init(opts: Options) Tabs {
        return .{
            .items = opts.items,
            .focus = FocusList.init(opts.items.len),
            .active_index = clampedIndex(opts.active_index, opts.items.len),
        };
    }

    /// Return whether the tab strip has no tabs.
    pub fn empty(self: *const Tabs) bool {
        return self.items.len == 0;
    }

    /// Return the currently focused tab index.
    ///
    /// When the tab strip is empty, this returns `0`. Callers should check
    /// `empty()` before using the result as an item index.
    pub fn focusedIndex(self: *const Tabs) usize {
        return self.focus.focused();
    }

    /// Return the currently active tab index.
    ///
    /// When the tab strip is empty, this returns `0`.
    pub fn activeIndex(self: *const Tabs) usize {
        if (self.empty()) return 0;
        return clampedIndex(self.active_index, self.items.len);
    }

    /// Return the active tab label, or null when there are no tabs.
    pub fn activeLabel(self: *const Tabs) ?[]const u8 {
        if (self.empty()) return null;
        return self.items[self.activeIndex()];
    }

    /// Apply a component message.
    pub fn update(self: *Tabs, msg: Msg) void {
        switch (msg) {
            .move_prev => self.focus.movePrev(),
            .move_next => self.focus.moveNext(),
            .set_active => |index| self.active_index = clampedIndex(index, self.items.len),
            .activate => |index| self.active_index = clampedIndex(index, self.items.len),
        }
    }

    /// Convert a Chasen event into a `Tabs` message when applicable.
    ///
    /// Left/Up move focus to the previous tab. Right/Down move focus to the
    /// next tab. Space without command-style modifiers and Enter activate the
    /// focused tab. Empty tab strips do not emit activation messages.
    pub fn handleEvent(self: *const Tabs, event: chasen.Event) ?Msg {
        return switch (event) {
            .key_press => |key| keyToMsg(self, key),
            else => null,
        };
    }

    /// Draw the tabs into the provided one-line surface region.
    pub fn view(self: *const Tabs, surface: *chasen.Surface, opts: ViewOptions) void {
        const width = surface.size().width;
        if (width == 0) return;

        if (self.empty()) {
            _ = surface.textAt(0, 0, opts.empty_label, opts.empty_style);
            if (opts.show_cursor) surface.showCursor(0, 0);
            return;
        }

        var col: u16 = 0;
        var focused_col: ?u16 = null;
        for (self.items, 0..) |item, i| {
            const tab_width = tabWidth(opts, item);
            if (col >= width or tab_width > width - col) break;

            const focused = self.focus.isFocused(i);
            const active = self.activeIndex() == i;
            if (focused) focused_col = @min(col + 1, width - 1);

            _ = surface.textAt(col, 0, opts.left_marker, opts.marker_style);
            if (tab_width > 1) {
                _ = surface.textAt(col + 1, 0, item, itemStyle(opts, focused, active));
            }
            if (tab_width > 2) {
                _ = surface.textAt(col + tab_width - 1, 0, opts.right_marker, opts.marker_style);
            }

            col += tab_width;
            if (col >= width) break;
            col += @min(opts.gap, width - col);
        }

        if (opts.show_cursor) {
            if (focused_col) |cursor_col| surface.showCursor(cursor_col, 0);
        }
    }
};

fn keyToMsg(tabs: *const Tabs, key: chasen.Key) ?Tabs.Msg {
    if (key.matches(chasen.Key.left, .{}) or key.matches(chasen.Key.up, .{})) return .move_prev;
    if (key.matches(chasen.Key.right, .{}) or key.matches(chasen.Key.down, .{})) return .move_next;
    if (selectable.isActivationKey(key)) {
        if (tabs.empty()) return null;
        return .{ .activate = tabs.focusedIndex() };
    }
    return null;
}

fn itemStyle(opts: Tabs.ViewOptions, focused: bool, active: bool) chasen.TextStyle {
    if (focused and active) return opts.focused_active_style;
    if (focused) return opts.focused_style;
    if (active) return opts.active_style;
    return opts.item_style;
}

fn tabWidth(opts: Tabs.ViewOptions, label: []const u8) u16 {
    return chasen.text.displayWidth(opts.left_marker) + chasen.text.displayWidth(label) + chasen.text.displayWidth(opts.right_marker);
}

fn clampedIndex(index: usize, len: usize) usize {
    if (len == 0) return 0;
    return @min(index, len - 1);
}

test "Tabs initializes with borrowed items and active index" {
    const items = [_][]const u8{ "Overview", "Details", "Logs" };
    const tabs = Tabs.init(.{ .items = &items, .active_index = 1 });

    try std.testing.expectEqual(@as(usize, 3), tabs.items.len);
    try std.testing.expectEqual(@as(usize, 0), tabs.focusedIndex());
    try std.testing.expectEqual(@as(usize, 1), tabs.activeIndex());
    try std.testing.expectEqualStrings("Details", tabs.activeLabel().?);
    try std.testing.expect(!tabs.empty());
}

test "Tabs clamps initial and explicit active index" {
    const items = [_][]const u8{ "Overview", "Details" };
    var tabs = Tabs.init(.{ .items = &items, .active_index = 99 });

    try std.testing.expectEqual(@as(usize, 1), tabs.activeIndex());

    tabs.update(.{ .set_active = 99 });
    try std.testing.expectEqual(@as(usize, 1), tabs.activeIndex());
}

test "Tabs handles empty items" {
    const tabs = Tabs.init(.{});

    try std.testing.expect(tabs.empty());
    try std.testing.expectEqual(@as(usize, 0), tabs.focusedIndex());
    try std.testing.expectEqual(@as(usize, 0), tabs.activeIndex());
    try std.testing.expect(tabs.activeLabel() == null);
}

test "Tabs update moves focus and activates focused tab" {
    const items = [_][]const u8{ "Overview", "Details" };
    var tabs = Tabs.init(.{ .items = &items });

    tabs.update(.move_prev);
    try std.testing.expectEqual(@as(usize, 0), tabs.focusedIndex());

    tabs.update(.move_next);
    try std.testing.expectEqual(@as(usize, 1), tabs.focusedIndex());

    tabs.update(.{ .activate = tabs.focusedIndex() });
    try std.testing.expectEqual(@as(usize, 1), tabs.activeIndex());

    tabs.update(.move_next);
    try std.testing.expectEqual(@as(usize, 1), tabs.focusedIndex());
}

test "Tabs maps keyboard events to messages" {
    const items = [_][]const u8{ "Overview", "Details" };
    var tabs = Tabs.init(.{ .items = &items });

    try std.testing.expectEqual(Tabs.Msg.move_prev, tabs.handleEvent(.{
        .key_press = .{ .codepoint = chasen.Key.left },
    }).?);
    try std.testing.expectEqual(Tabs.Msg.move_next, tabs.handleEvent(.{
        .key_press = .{ .codepoint = chasen.Key.right },
    }).?);

    tabs.update(.move_next);
    try std.testing.expectEqual(Tabs.Msg{ .activate = 1 }, tabs.handleEvent(.{
        .key_press = .{ .codepoint = '\r' },
    }).?);
}

test "Tabs ignores modified Space and does not activate empty tabs" {
    const items = [_][]const u8{"Overview"};
    var tabs = Tabs.init(.{ .items = &items });

    try std.testing.expect(tabs.handleEvent(.{
        .key_press = .{ .codepoint = ' ', .text = " ", .mods = .{ .ctrl = true } },
    }) == null);

    const empty = Tabs.init(.{});
    try std.testing.expect(empty.handleEvent(.{
        .key_press = .{ .codepoint = '\r' },
    }) == null);
}
