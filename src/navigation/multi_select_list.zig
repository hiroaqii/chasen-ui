const std = @import("std");
const chasen = @import("chasen");
const FocusList = @import("focus_list.zig").FocusList;
const selectable = @import("selectable.zig");

/// A vertical list with local focus and multi-selection state.
///
/// `MultiSelectList` is allocation-free and stores selection in a 64-bit mask.
/// Applications still decide what the selected items mean and how to apply
/// them to the surrounding model.
pub const MultiSelectList = struct {
    /// Maximum number of selectable items in the initial implementation.
    pub const max_items = 64;

    /// Item labels borrowed by the component.
    items: []const []const u8 = &.{},
    /// Local focus state for the list items.
    focus: FocusList = .{},
    /// Bit mask of selected item indices.
    selected_mask: u64 = 0,

    /// Initial values used when constructing a `MultiSelectList`.
    pub const Options = struct {
        /// Item labels borrowed by the component for its lifetime.
        items: []const []const u8 = &.{},
        /// Initial selected item mask. Bits beyond the item count are cleared.
        selected_mask: u64 = 0,
    };

    /// Messages understood by `MultiSelectList.update`.
    pub const Msg = union(enum) {
        /// Move focus to the previous item.
        move_prev,
        /// Move focus to the next item.
        move_next,
        /// Toggle the selected state for an item.
        toggle: usize,
        /// Clear all selected items.
        clear,
    };

    /// Rendering options for `MultiSelectList.view`.
    pub const ViewOptions = struct {
        /// Style used for unselected, unfocused item labels.
        item_style: chasen.TextStyle = .{},
        /// Style used for focused item labels.
        focused_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for selected item labels.
        selected_style: chasen.TextStyle = .{ .fg = .{ .index = 2 } },
        /// Style used for selected and focused item labels.
        focused_selected_style: chasen.TextStyle = .{ .bold = true, .fg = .{ .index = 2 } },
        /// Style used for selection markers.
        marker_style: chasen.TextStyle = .{ .dim = true },
        /// Marker shown before selected items. Expected to occupy 3 display cells.
        selected_marker: []const u8 = "[x]",
        /// Marker shown before unselected items. Expected to occupy 3 display cells.
        marker: []const u8 = "[ ]",
        /// Whether `view` should place the terminal cursor on the focused row.
        show_cursor: bool = true,
    };

    /// Create a multi-select list.
    pub fn init(opts: Options) MultiSelectList {
        return .{
            .items = opts.items,
            .focus = FocusList.init(maxSelectable(opts.items.len)),
            .selected_mask = opts.selected_mask & validMask(opts.items.len),
        };
    }

    /// Return the currently focused item index.
    ///
    /// When the list is empty, this returns `0`. Callers should check
    /// `empty()` before using the result as an item index.
    pub fn focusedIndex(self: *const MultiSelectList) usize {
        return self.focus.focused();
    }

    /// Return whether the list has no items.
    pub fn empty(self: *const MultiSelectList) bool {
        return self.items.len == 0;
    }

    /// Return whether `index` is selected.
    pub fn isSelected(self: *const MultiSelectList, index: usize) bool {
        if (index >= maxSelectable(self.items.len)) return false;
        return self.selected_mask & bit(index) != 0;
    }

    /// Return the number of selected items.
    pub fn selectedCount(self: *const MultiSelectList) usize {
        return @popCount(self.selected_mask & validMask(self.items.len));
    }

    /// Apply a component message.
    pub fn update(self: *MultiSelectList, msg: Msg) void {
        switch (msg) {
            .move_prev => self.focus.movePrev(),
            .move_next => self.focus.moveNext(),
            .toggle => |index| self.toggle(index),
            .clear => self.selected_mask = 0,
        }
    }

    /// Convert a Chasen event into a `MultiSelectList` message when applicable.
    ///
    /// Up/Down move focus. Space without command-style modifiers and Enter
    /// toggle the focused item. Empty lists do not emit toggle messages.
    pub fn handleEvent(self: *const MultiSelectList, event: chasen.Event) ?Msg {
        return switch (event) {
            .key_press => |key| keyToMsg(self, key),
            else => null,
        };
    }

    /// Draw the multi-select list into the provided vertical surface region.
    pub fn view(self: *const MultiSelectList, surface: *chasen.Surface, opts: ViewOptions) void {
        const size = surface.size();
        const width = size.width;
        const height = size.height;
        if (width == 0 or height == 0) return;

        const visible_count = @min(@min(self.items.len, max_items), @as(usize, height));
        for (self.items[0..visible_count], 0..) |item, i| {
            const row: u16 = @intCast(i);
            const focused = self.focus.isFocused(i);
            const selected = self.isSelected(i);
            const marker = if (selected) opts.selected_marker else opts.marker;

            _ = surface.borrowTextAt(0, row, marker, opts.marker_style);
            if (width > 4) {
                _ = surface.borrowTextAt(4, row, item, itemStyle(opts, focused, selected));
            }
        }

        if (opts.show_cursor and self.items.len > 0 and self.focusedIndex() < visible_count) {
            const cursor_row: u16 = @intCast(self.focusedIndex());
            surface.showCursor(@min(@as(u16, 4), width - 1), cursor_row);
        }
    }

    fn toggle(self: *MultiSelectList, index: usize) void {
        if (index >= maxSelectable(self.items.len)) return;
        self.selected_mask ^= bit(index);
    }
};

fn keyToMsg(list: *const MultiSelectList, key: chasen.Key) ?MultiSelectList.Msg {
    if (key.matches(chasen.Key.up, .{})) return .move_prev;
    if (key.matches(chasen.Key.down, .{})) return .move_next;
    if (selectable.isActivationKey(key)) {
        if (list.empty()) return null;
        return .{ .toggle = list.focusedIndex() };
    }
    return null;
}

fn itemStyle(opts: MultiSelectList.ViewOptions, focused: bool, selected: bool) chasen.TextStyle {
    if (focused and selected) return opts.focused_selected_style;
    if (focused) return opts.focused_style;
    if (selected) return opts.selected_style;
    return opts.item_style;
}

fn validMask(len: usize) u64 {
    const count = maxSelectable(len);
    if (count == MultiSelectList.max_items) return std.math.maxInt(u64);
    return (@as(u64, 1) << @intCast(count)) - 1;
}

fn maxSelectable(len: usize) usize {
    return @min(len, MultiSelectList.max_items);
}

fn bit(index: usize) u64 {
    return @as(u64, 1) << @intCast(index);
}

test "MultiSelectList initializes with clamped selected mask" {
    const items = [_][]const u8{ "Alpha", "Beta" };
    const list = MultiSelectList.init(.{
        .items = &items,
        .selected_mask = 0b111,
    });

    try std.testing.expectEqual(@as(usize, 0), list.focusedIndex());
    try std.testing.expect(list.isSelected(0));
    try std.testing.expect(list.isSelected(1));
    try std.testing.expect(!list.isSelected(2));
    try std.testing.expectEqual(@as(usize, 2), list.selectedCount());
}

test "MultiSelectList limits selection and focus to max items" {
    const items = [_][]const u8{"Item"} ** (MultiSelectList.max_items + 1);
    var list = MultiSelectList.init(.{
        .items = &items,
        .selected_mask = std.math.maxInt(u64),
    });

    try std.testing.expect(list.isSelected(MultiSelectList.max_items - 1));
    try std.testing.expect(!list.isSelected(MultiSelectList.max_items));
    try std.testing.expectEqual(@as(usize, MultiSelectList.max_items), list.selectedCount());

    for (0..MultiSelectList.max_items + 8) |_| {
        list.update(.move_next);
    }
    try std.testing.expect(list.focusedIndex() < MultiSelectList.max_items);
}

test "MultiSelectList toggles selected items" {
    const items = [_][]const u8{ "Alpha", "Beta" };
    var list = MultiSelectList.init(.{ .items = &items });

    list.update(.{ .toggle = 1 });
    try std.testing.expect(list.isSelected(1));
    try std.testing.expectEqual(@as(usize, 1), list.selectedCount());

    list.update(.{ .toggle = 1 });
    try std.testing.expect(!list.isSelected(1));
    try std.testing.expectEqual(@as(usize, 0), list.selectedCount());
}

test "MultiSelectList update moves focus and clears selection" {
    const items = [_][]const u8{ "Alpha", "Beta" };
    var list = MultiSelectList.init(.{ .items = &items, .selected_mask = 0b11 });

    list.update(.move_next);
    try std.testing.expectEqual(@as(usize, 1), list.focusedIndex());

    list.update(.clear);
    try std.testing.expectEqual(@as(usize, 0), list.selectedCount());
}

test "MultiSelectList maps keyboard events to messages" {
    const items = [_][]const u8{ "Alpha", "Beta" };
    var list = MultiSelectList.init(.{ .items = &items });

    try std.testing.expectEqual(MultiSelectList.Msg.move_next, list.handleEvent(.{
        .key_press = .{ .codepoint = chasen.Key.down },
    }).?);
    list.update(.move_next);
    try std.testing.expectEqual(MultiSelectList.Msg{ .toggle = 1 }, list.handleEvent(.{
        .key_press = .{ .codepoint = '\r' },
    }).?);
}

test "MultiSelectList does not toggle empty lists" {
    var list = MultiSelectList.init(.{});

    try std.testing.expect(list.handleEvent(.{
        .key_press = .{ .codepoint = '\r' },
    }) == null);
}
