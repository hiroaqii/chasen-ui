const std = @import("std");
const chasen = @import("chasen");
const FocusList = @import("focus_list.zig").FocusList;
const selectable = @import("selectable.zig");

/// A vertical command menu with local focus state.
///
/// `Menu` borrows command labels and optional shortcut hints. It owns only the
/// focused item; applications decide what activating a menu item does and how
/// to store any active screen or command result.
pub const Menu = struct {
    /// One borrowed command row.
    pub const Item = struct {
        /// Command label shown in the menu.
        label: []const u8,
        /// Optional shortcut hint shown to the right of the label.
        shortcut: ?[]const u8 = null,
    };

    /// Menu items borrowed by the component.
    items: []const Item = &.{},
    /// Local focus state for the menu items.
    focus: FocusList = .{},

    /// Initial values used when constructing a `Menu`.
    pub const Options = struct {
        /// Menu items borrowed by the component for its lifetime.
        items: []const Item = &.{},
    };

    /// Messages understood by `Menu.update`.
    pub const Msg = union(enum) {
        /// Move focus to the previous item.
        move_prev,
        /// Move focus to the next item.
        move_next,
        /// The currently focused command was activated.
        activate: usize,
    };

    /// Rendering options for `Menu.view`.
    pub const ViewOptions = struct {
        /// Column where shortcut hints should start inside the menu region.
        shortcut_col: u16 = 18,
        /// Style used for unfocused item labels.
        item_style: chasen.TextStyle = .{},
        /// Style used for the focused item label.
        focused_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for shortcut hints.
        shortcut_style: chasen.TextStyle = .{ .dim = true },
        /// Style used for the focus marker.
        marker_style: chasen.TextStyle = .{ .dim = true },
        /// Marker shown before the focused item.
        ///
        /// The initial Menu layout assumes this occupies one display cell.
        focused_marker: []const u8 = ">",
        /// Marker shown before other items.
        ///
        /// The initial Menu layout assumes this occupies one display cell.
        marker: []const u8 = " ",
        /// Whether `view` should place the terminal cursor on the focused row.
        show_cursor: bool = true,
    };

    /// Create a menu.
    pub fn init(opts: Options) Menu {
        return .{
            .items = opts.items,
            .focus = FocusList.init(opts.items.len),
        };
    }

    /// Return the currently focused item index.
    ///
    /// When the menu is empty, this returns `0`. Callers should check
    /// `empty()` before using the result as an item index.
    pub fn focusedIndex(self: *const Menu) usize {
        return self.focus.focused();
    }

    /// Return the currently focused item, or null when the menu is empty.
    pub fn focusedItem(self: *const Menu) ?Item {
        if (self.empty()) return null;
        return self.items[self.focusedIndex()];
    }

    /// Return whether the menu has no items.
    pub fn empty(self: *const Menu) bool {
        return self.items.len == 0;
    }

    /// Apply a component message.
    pub fn update(self: *Menu, msg: Msg) void {
        switch (msg) {
            .move_prev => self.focus.movePrev(),
            .move_next => self.focus.moveNext(),
            .activate => {},
        }
    }

    /// Convert a Chasen event into a `Menu` message when applicable.
    ///
    /// Up/Down move focus. Space without command-style modifiers and Enter
    /// activate the focused command. Empty menus do not emit activation.
    pub fn handleEvent(self: *const Menu, event: chasen.Event) ?Msg {
        return switch (event) {
            .key_press => |key| keyToMsg(self, key),
            else => null,
        };
    }

    /// Draw the menu into the provided vertical surface region.
    pub fn view(self: *const Menu, surface: *chasen.Surface, opts: ViewOptions) void {
        const size = surface.size();
        const width = size.width;
        const height = size.height;
        if (width == 0 or height == 0) return;

        const visible_count = @min(self.items.len, @as(usize, height));
        for (self.items[0..visible_count], 0..) |item, i| {
            const row: u16 = @intCast(i);
            const focused = self.focus.isFocused(i);
            const marker = if (focused) opts.focused_marker else opts.marker;
            const label_style = if (focused) opts.focused_style else opts.item_style;

            _ = surface.borrowTextAt(0, row, marker, opts.marker_style);
            if (width > 2) {
                _ = surface.borrowTextAt(2, row, item.label, label_style);
            }
            if (item.shortcut) |shortcut| {
                if (opts.shortcut_col < width) {
                    _ = surface.borrowTextAt(opts.shortcut_col, row, shortcut, opts.shortcut_style);
                }
            }
        }

        if (opts.show_cursor and self.items.len > 0 and self.focusedIndex() < visible_count) {
            const cursor_row: u16 = @intCast(self.focusedIndex());
            surface.showCursor(@min(@as(u16, 2), width - 1), cursor_row);
        }
    }
};

fn keyToMsg(menu: *const Menu, key: chasen.Key) ?Menu.Msg {
    if (key.matches(chasen.Key.up, .{})) return .move_prev;
    if (key.matches(chasen.Key.down, .{})) return .move_next;
    if (selectable.isActivationKey(key)) {
        if (menu.empty()) return null;
        return .{ .activate = menu.focusedIndex() };
    }
    return null;
}

test "Menu initializes with borrowed items and focus at first item" {
    const items = [_]Menu.Item{
        .{ .label = "Dashboard", .shortcut = "g d" },
        .{ .label = "Settings", .shortcut = "g s" },
    };
    const menu = Menu.init(.{ .items = &items });

    try std.testing.expectEqual(@as(usize, 2), menu.items.len);
    try std.testing.expectEqualStrings("Dashboard", menu.focusedItem().?.label);
    try std.testing.expectEqual(@as(usize, 0), menu.focusedIndex());
    try std.testing.expect(!menu.empty());
}

test "Menu handles empty items" {
    const menu = Menu.init(.{});

    try std.testing.expect(menu.empty());
    try std.testing.expect(menu.focusedItem() == null);
    try std.testing.expectEqual(@as(usize, 0), menu.focusedIndex());
}

test "Menu update moves focus with clamp behavior" {
    const items = [_]Menu.Item{
        .{ .label = "Dashboard" },
        .{ .label = "Settings" },
    };
    var menu = Menu.init(.{ .items = &items });

    menu.update(.move_prev);
    try std.testing.expectEqual(@as(usize, 0), menu.focusedIndex());

    menu.update(.move_next);
    try std.testing.expectEqual(@as(usize, 1), menu.focusedIndex());

    menu.update(.move_next);
    try std.testing.expectEqual(@as(usize, 1), menu.focusedIndex());

    menu.update(.move_prev);
    try std.testing.expectEqual(@as(usize, 0), menu.focusedIndex());
}

test "Menu maps keyboard events to messages" {
    const items = [_]Menu.Item{
        .{ .label = "Dashboard" },
        .{ .label = "Settings" },
    };
    var menu = Menu.init(.{ .items = &items });

    try std.testing.expectEqual(Menu.Msg.move_next, menu.handleEvent(.{
        .key_press = .{ .codepoint = chasen.Key.down },
    }).?);
    menu.update(.move_next);
    try std.testing.expectEqual(Menu.Msg{ .activate = 1 }, menu.handleEvent(.{
        .key_press = .{ .codepoint = '\r' },
    }).?);
}

test "Menu ignores modified Space and does not activate empty menus" {
    const items = [_]Menu.Item{.{ .label = "Dashboard" }};
    var menu = Menu.init(.{ .items = &items });

    try std.testing.expect(menu.handleEvent(.{
        .key_press = .{ .codepoint = ' ', .text = " ", .mods = .{ .ctrl = true } },
    }) == null);

    const empty = Menu.init(.{});
    try std.testing.expect(empty.handleEvent(.{
        .key_press = .{ .codepoint = '\r' },
    }) == null);
}
