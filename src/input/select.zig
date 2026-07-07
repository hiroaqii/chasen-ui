const std = @import("std");
const chasen = @import("chasen");
const selectable = @import("../navigation/selectable.zig");

/// A small one-line option picker with local selected state.
///
/// `Select` borrows its item labels and owns only the selected index. The
/// initial component is intentionally not a dropdown: it draws the current item
/// in a one-line region and lets Left/Right or Up/Down move through options.
/// Applications decide what the selected value means and how to combine it
/// with larger form state.
pub const Select = struct {
    /// Item labels borrowed by the component.
    items: []const []const u8 = &.{},
    /// Currently selected item index.
    selected_index: usize = 0,

    /// Initial values used when constructing a `Select`.
    pub const Options = struct {
        /// Item labels borrowed by the component for its lifetime.
        items: []const []const u8 = &.{},
        /// Initial selected item index. Values outside `items` are clamped.
        selected_index: usize = 0,
    };

    /// Messages understood by `Select.update`.
    ///
    /// Applications can either use `handleEvent` to create these messages from
    /// Chasen key events, or construct them directly for custom bindings.
    pub const Msg = union(enum) {
        /// Move selection to the previous item.
        move_prev,
        /// Move selection to the next item.
        move_next,
        /// Set the selected item index explicitly. Values outside `items` are clamped.
        set_selected: usize,
        /// The currently selected item was activated.
        activate: usize,
    };

    /// Rendering options for `Select.view`.
    pub const ViewOptions = struct {
        /// Style used for the selected item label.
        item_style: chasen.TextStyle = .{},
        /// Style used for the previous/next markers.
        marker_style: chasen.TextStyle = .{ .dim = true },
        /// Marker shown at the left edge.
        ///
        /// The initial layout assumes this occupies one display cell.
        prev_marker: []const u8 = "<",
        /// Marker shown at the right edge.
        ///
        /// The initial layout assumes this occupies one display cell.
        next_marker: []const u8 = ">",
        /// Placeholder shown when the select has no items.
        empty_label: []const u8 = "(empty)",
        /// Style used for `empty_label`.
        empty_style: chasen.TextStyle = .{ .dim = true },
        /// Whether `view` should place the terminal cursor on the left marker.
        show_cursor: bool = true,
    };

    /// Create a select.
    pub fn init(opts: Options) Select {
        return .{
            .items = opts.items,
            .selected_index = clampedIndex(opts.selected_index, opts.items.len),
        };
    }

    /// Return whether the select has no options.
    pub fn empty(self: *const Select) bool {
        return self.items.len == 0;
    }

    /// Return the currently selected item index.
    ///
    /// When the select is empty, this returns `0`. Callers should check
    /// `items.len > 0` before using the result as an item index. The returned
    /// index is clamped so callers still get a valid item index if public fields
    /// were changed directly.
    pub fn selectedIndex(self: *const Select) usize {
        if (self.empty()) return 0;
        return clampedIndex(self.selected_index, self.items.len);
    }

    /// Return the selected item label, or `null` when the select is empty.
    pub fn selectedLabel(self: *const Select) ?[]const u8 {
        if (self.empty()) return null;
        return self.items[self.selectedIndex()];
    }

    /// Apply a component message.
    pub fn update(self: *Select, msg: Msg) void {
        switch (msg) {
            .move_prev => self.movePrev(),
            .move_next => self.moveNext(),
            .set_selected => |index| self.selected_index = clampedIndex(index, self.items.len),
            .activate => {},
        }
    }

    /// Convert a Chasen event into a `Select` message when the event belongs to
    /// the component.
    ///
    /// Left/Up move to the previous item. Right/Down move to the next item.
    /// Space without command-style modifiers and Enter activate the current
    /// selection. Empty selects do not emit activation messages.
    pub fn handleEvent(self: *const Select, event: chasen.Event) ?Msg {
        return switch (event) {
            .key_press => |key| keyToMsg(self, key),
            else => null,
        };
    }

    /// Draw the select into the provided one-line surface region.
    pub fn view(self: *const Select, surface: *chasen.Surface, opts: ViewOptions) void {
        const width = surface.size().width;
        if (width == 0) return;

        _ = surface.borrowTextAt(0, 0, opts.prev_marker, opts.marker_style);
        if (width > 1) {
            _ = surface.borrowTextAt(width - 1, 0, opts.next_marker, opts.marker_style);
        }

        const label = self.selectedLabel() orelse opts.empty_label;
        const label_style = if (self.empty()) opts.empty_style else opts.item_style;
        if (width > 4) {
            drawClippedLabel(surface, 2, width - 1, label, label_style);
        } else if (width > 2) {
            drawClippedLabel(surface, 1, width - 1, label, label_style);
        }

        if (opts.show_cursor) {
            surface.showCursor(0, 0);
        }
    }

    fn movePrev(self: *Select) void {
        if (self.empty()) return;
        if (self.selected_index > 0) self.selected_index -= 1;
    }

    fn moveNext(self: *Select) void {
        if (self.empty()) return;
        if (self.selected_index + 1 < self.items.len) self.selected_index += 1;
    }
};

fn keyToMsg(select: *const Select, key: chasen.Key) ?Select.Msg {
    if (key.matches(chasen.Key.left, .{}) or key.matches(chasen.Key.up, .{})) return .move_prev;
    if (key.matches(chasen.Key.right, .{}) or key.matches(chasen.Key.down, .{})) return .move_next;
    if (selectable.isActivationKey(key)) {
        if (select.empty()) return null;
        return .{ .activate = select.selectedIndex() };
    }
    return null;
}

fn clampedIndex(index: usize, len: usize) usize {
    if (len == 0) return 0;
    return @min(index, len - 1);
}

fn drawClippedLabel(surface: *chasen.Surface, col: u16, max_col: u16, label: []const u8, style: chasen.TextStyle) void {
    if (label.len == 0 or col >= max_col) return;
    const clipped = chasen.text.clipToWidth(label, max_col - col);
    if (clipped.len == 0) return;
    _ = surface.borrowTextAt(col, 0, clipped, style);
}

test "Select initializes with borrowed items and selected index" {
    const items = [_][]const u8{ "Small", "Medium", "Large" };
    const select = Select.init(.{ .items = &items, .selected_index = 1 });

    try std.testing.expectEqual(@as(usize, 3), select.items.len);
    try std.testing.expectEqual(@as(usize, 1), select.selectedIndex());
    try std.testing.expectEqualStrings("Medium", select.selectedLabel().?);
    try std.testing.expect(!select.empty());
}

test "Select clamps initial and explicit selected index" {
    const items = [_][]const u8{ "Small", "Medium" };
    var select = Select.init(.{ .items = &items, .selected_index = 99 });

    try std.testing.expectEqual(@as(usize, 1), select.selectedIndex());

    select.update(.{ .set_selected = 99 });
    try std.testing.expectEqual(@as(usize, 1), select.selectedIndex());
}

test "Select accessors clamp when public fields are changed directly" {
    const items = [_][]const u8{ "Small", "Medium" };
    var select = Select.init(.{ .items = &items });

    select.selected_index = 99;

    try std.testing.expectEqual(@as(usize, 1), select.selectedIndex());
    try std.testing.expectEqualStrings("Medium", select.selectedLabel().?);
}

test "Select handles empty items" {
    const select = Select.init(.{});

    try std.testing.expect(select.empty());
    try std.testing.expectEqual(@as(usize, 0), select.selectedIndex());
    try std.testing.expect(select.selectedLabel() == null);
}

test "Select clips long labels before right marker" {
    const items = [_][]const u8{"abcdef"};
    const select = Select.init(.{ .items = &items });

    var ts: chasen.testing.TestSurface = undefined;
    try ts.init(6, 1);
    defer ts.deinit();

    select.view(&ts.surface, .{ .show_cursor = false });

    try ts.expectCellText(0, 0, "<");
    try ts.expectCellText(2, 0, "a");
    try ts.expectCellText(4, 0, "c");
    try ts.expectCellText(5, 0, ">");
}

test "Select update moves selection with clamp behavior" {
    const items = [_][]const u8{ "Small", "Medium" };
    var select = Select.init(.{ .items = &items });

    select.update(.move_prev);
    try std.testing.expectEqual(@as(usize, 0), select.selectedIndex());

    select.update(.move_next);
    try std.testing.expectEqual(@as(usize, 1), select.selectedIndex());

    select.update(.move_next);
    try std.testing.expectEqual(@as(usize, 1), select.selectedIndex());

    select.update(.move_prev);
    try std.testing.expectEqual(@as(usize, 0), select.selectedIndex());
}

test "Select maps keyboard events to messages" {
    const items = [_][]const u8{ "Small", "Medium" };
    var select = Select.init(.{ .items = &items });

    try std.testing.expectEqual(Select.Msg.move_prev, select.handleEvent(.{
        .key_press = .{ .codepoint = chasen.Key.left },
    }).?);
    try std.testing.expectEqual(Select.Msg.move_prev, select.handleEvent(.{
        .key_press = .{ .codepoint = chasen.Key.up },
    }).?);
    try std.testing.expectEqual(Select.Msg.move_next, select.handleEvent(.{
        .key_press = .{ .codepoint = chasen.Key.right },
    }).?);
    try std.testing.expectEqual(Select.Msg.move_next, select.handleEvent(.{
        .key_press = .{ .codepoint = chasen.Key.down },
    }).?);
    try std.testing.expectEqual(Select.Msg{ .activate = 0 }, select.handleEvent(.{
        .key_press = .{ .codepoint = '\r' },
    }).?);

    select.update(.move_next);
    try std.testing.expectEqual(Select.Msg{ .activate = 1 }, select.handleEvent(.{
        .key_press = .{ .codepoint = ' ', .text = " " },
    }).?);
}

test "Select ignores modified Space and does not activate empty selects" {
    const items = [_][]const u8{"Small"};
    var select = Select.init(.{ .items = &items });

    try std.testing.expect(select.handleEvent(.{
        .key_press = .{ .codepoint = ' ', .text = " ", .mods = .{ .ctrl = true } },
    }) == null);

    const empty = Select.init(.{});
    try std.testing.expect(empty.handleEvent(.{
        .key_press = .{ .codepoint = '\r' },
    }) == null);
}
