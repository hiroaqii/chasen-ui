const std = @import("std");
const chasen = @import("chasen");
const FocusList = @import("focus_list.zig").FocusList;
const nav_util = @import("nav_util.zig");
const selectable = @import("selectable.zig");

/// A fixed list of borrowed text items with local focus state.
///
/// `List` owns only the focused index. It borrows the item labels and does not
/// own selection policy: applications decide what activation means and may pass
/// a selected index to `view` for display.
///
/// The initial API is intentionally small. It renders a simple vertical list,
/// clamps focus at the first and last item, and does not scroll, wrap, skip
/// disabled items, or manage animation state.
pub const List = struct {
    /// Item labels borrowed by the component.
    items: []const []const u8 = &.{},
    /// Local focus state for the list items.
    focus: FocusList = .{},

    /// Initial values used when constructing a `List`.
    pub const Options = struct {
        /// Item labels borrowed by the component for its lifetime.
        items: []const []const u8 = &.{},
    };

    /// Messages understood by `List.update`.
    ///
    /// Applications can either use `handleEvent` to create these messages from
    /// Chasen key events, or construct them directly for custom bindings.
    pub const Msg = union(enum) {
        /// Move focus to the previous item.
        move_prev,
        /// Move focus to the next item.
        move_next,
        /// The currently focused item was activated.
        activate: usize,
    };

    /// Rendering options for `List.view`.
    pub const ViewOptions = struct {
        /// Optional app-owned selected index to render differently.
        selected_index: ?usize = null,
        /// Style used for unfocused, unselected item labels.
        item_style: chasen.TextStyle = .{},
        /// Style used for the focused item label.
        focused_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for the selected item label when it is not focused.
        selected_style: chasen.TextStyle = .{ .fg = .{ .index = 2 } },
        /// Style used for the selected item label when it is focused.
        focused_selected_style: chasen.TextStyle = .{ .bold = true, .fg = .{ .index = 2 } },
        /// Style used for the focus marker.
        marker_style: chasen.TextStyle = .{ .dim = true },
        /// Marker shown before the focused item.
        ///
        /// The initial List layout assumes this occupies one display cell.
        focused_marker: []const u8 = ">",
        /// Marker shown before other items.
        ///
        /// The initial List layout assumes this occupies one display cell.
        marker: []const u8 = " ",
        /// Whether `view` should place the terminal cursor on the focused row.
        show_cursor: bool = true,
    };

    /// Create a list.
    pub fn init(opts: Options) List {
        return .{
            .items = opts.items,
            .focus = FocusList.init(opts.items.len),
        };
    }

    /// Return the currently focused item index.
    ///
    /// When the list is empty, this returns `0`. Callers should check
    /// `items.len > 0` before using the result as an item index.
    pub fn focusedIndex(self: *const List) usize {
        return self.focus.focused();
    }

    /// Return whether the list has any items.
    pub fn empty(self: *const List) bool {
        return self.items.len == 0;
    }

    /// Apply a component message.
    pub fn update(self: *List, msg: Msg) void {
        switch (msg) {
            .move_prev => self.focus.movePrev(),
            .move_next => self.focus.moveNext(),
            .activate => {},
        }
    }

    /// Convert a Chasen event into a `List` message when the event belongs to
    /// the component.
    ///
    /// Up/Down move focus. Space without command-style modifiers and Enter
    /// activate the focused item. Ctrl, Alt, Super, Hyper, and Meta Space are
    /// ignored so applications can reserve those bindings for app-level
    /// shortcuts.
    pub fn handleEvent(self: *const List, event: chasen.Event) ?Msg {
        return switch (event) {
            .key_press => |key| keyToMsg(self, key),
            else => null,
        };
    }

    /// Draw the list into the provided vertical surface region.
    pub fn view(self: *const List, surface: *chasen.Surface, opts: ViewOptions) void {
        const size = surface.size();
        const width = size.width;
        const height = size.height;
        if (width == 0 or height == 0) return;

        const visible_count = @min(self.items.len, @as(usize, height));
        for (self.items[0..visible_count], 0..) |item, i| {
            const row: u16 = @intCast(i);
            const focused = self.focus.isFocused(i);
            const selected = opts.selected_index != null and opts.selected_index.? == i;
            const item_style = nav_util.fourStateStyle(.{
                .normal = opts.item_style,
                .focused = opts.focused_style,
                .selected = opts.selected_style,
                .focused_selected = opts.focused_selected_style,
            }, focused, selected);
            const marker = if (focused) opts.focused_marker else opts.marker;

            _ = surface.borrowTextAt(0, row, marker, opts.marker_style);
            if (width > 2) {
                _ = surface.borrowTextAt(2, row, item, item_style);
            }
        }

        if (opts.show_cursor and self.items.len > 0 and self.focusedIndex() < visible_count) {
            const cursor_row: u16 = @intCast(self.focusedIndex());
            surface.showCursor(@min(@as(u16, 2), width - 1), cursor_row);
        }
    }
};

fn keyToMsg(list: *const List, key: chasen.Key) ?List.Msg {
    if (key.matches(chasen.Key.up, .{})) return .move_prev;
    if (key.matches(chasen.Key.down, .{})) return .move_next;
    if (selectable.isActivationKey(key)) {
        if (list.empty()) return null;
        return .{ .activate = list.focusedIndex() };
    }
    return null;
}

test "List initializes with borrowed items and focus at first item" {
    const items = [_][]const u8{ "Alpha", "Beta" };
    const list = List.init(.{ .items = &items });

    try std.testing.expectEqual(@as(usize, 2), list.items.len);
    try std.testing.expectEqualStrings("Alpha", list.items[0]);
    try std.testing.expectEqual(@as(usize, 0), list.focusedIndex());
    try std.testing.expect(!list.empty());
}

test {
    _ = nav_util;
}

test "List handles empty items" {
    const list = List.init(.{});

    try std.testing.expect(list.empty());
    try std.testing.expectEqual(@as(usize, 0), list.focusedIndex());
}

test "List update moves focus with clamp behavior" {
    const items = [_][]const u8{ "Alpha", "Beta" };
    var list = List.init(.{ .items = &items });

    list.update(.move_prev);
    try std.testing.expectEqual(@as(usize, 0), list.focusedIndex());

    list.update(.move_next);
    try std.testing.expectEqual(@as(usize, 1), list.focusedIndex());

    list.update(.move_next);
    try std.testing.expectEqual(@as(usize, 1), list.focusedIndex());

    list.update(.move_prev);
    try std.testing.expectEqual(@as(usize, 0), list.focusedIndex());
}

test "List maps keyboard events to messages" {
    const items = [_][]const u8{ "Alpha", "Beta" };
    var list = List.init(.{ .items = &items });

    try std.testing.expectEqual(List.Msg.move_prev, list.handleEvent(.{
        .key_press = .{ .codepoint = chasen.Key.up },
    }).?);
    try std.testing.expectEqual(List.Msg.move_next, list.handleEvent(.{
        .key_press = .{ .codepoint = chasen.Key.down },
    }).?);
    try std.testing.expectEqual(List.Msg{ .activate = 0 }, list.handleEvent(.{
        .key_press = .{ .codepoint = '\r' },
    }).?);

    list.update(.move_next);
    try std.testing.expectEqual(List.Msg{ .activate = 1 }, list.handleEvent(.{
        .key_press = .{ .codepoint = ' ', .text = " " },
    }).?);
}

test "List ignores modified Space and unrelated events" {
    const items = [_][]const u8{"Alpha"};
    var list = List.init(.{ .items = &items });

    try std.testing.expect(list.handleEvent(.{
        .key_press = .{ .codepoint = ' ', .text = " ", .mods = .{ .ctrl = true } },
    }) == null);
    try std.testing.expect(list.handleEvent(.{
        .key_press = .{ .codepoint = 'x', .text = "x" },
    }) == null);
}

test "List does not activate empty lists" {
    var list = List.init(.{});

    try std.testing.expect(list.handleEvent(.{
        .key_press = .{ .codepoint = '\r' },
    }) == null);
    try std.testing.expect(list.handleEvent(.{
        .key_press = .{ .codepoint = ' ', .text = " " },
    }) == null);
}
