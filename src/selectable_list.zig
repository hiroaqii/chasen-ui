const std = @import("std");
const chasen = @import("chasen");
const List = @import("list.zig").List;

/// A vertical list with local focus and selected state.
///
/// `SelectableList` wraps `List` for the common case where activation should
/// store the selected item locally. Applications still decide what the selected
/// value means and how it affects the rest of their model.
pub const SelectableList = struct {
    /// Internal focused list state and borrowed item labels.
    list: List,
    /// Locally selected item index.
    selected_index: ?usize = null,

    /// Initial values used when constructing a `SelectableList`.
    pub const Options = struct {
        /// Item labels borrowed by the component for its lifetime.
        items: []const []const u8 = &.{},
        /// Initial selected item index. Values outside `items` are ignored.
        selected_index: ?usize = null,
    };

    /// Messages understood by `SelectableList.update`.
    pub const Msg = List.Msg;

    /// Rendering options for `SelectableList.view`.
    pub const ViewOptions = List.ViewOptions;

    /// Create a selectable list.
    pub fn init(opts: Options) SelectableList {
        return .{
            .list = List.init(.{ .items = opts.items }),
            .selected_index = clampedOptionalIndex(opts.selected_index, opts.items.len),
        };
    }

    /// Return the currently focused item index.
    ///
    /// When the list is empty, this returns `0`. Callers should check
    /// `empty()` before using the result as an item index.
    pub fn focusedIndex(self: *const SelectableList) usize {
        return self.list.focusedIndex();
    }

    /// Return the currently selected item index, or null when none is selected.
    pub fn selectedIndex(self: *const SelectableList) ?usize {
        return clampedOptionalIndex(self.selected_index, self.list.items.len);
    }

    /// Return the selected item label, or null when none is selected.
    pub fn selectedLabel(self: *const SelectableList) ?[]const u8 {
        const index = self.selectedIndex() orelse return null;
        return self.list.items[index];
    }

    /// Return whether the list has any items.
    pub fn empty(self: *const SelectableList) bool {
        return self.list.empty();
    }

    /// Apply a component message.
    pub fn update(self: *SelectableList, msg: Msg) void {
        switch (msg) {
            .move_prev, .move_next => self.list.update(msg),
            .activate => |index| self.selected_index = clampedOptionalIndex(index, self.list.items.len),
        }
    }

    /// Convert a Chasen event into a `SelectableList` message when applicable.
    pub fn handleEvent(self: *const SelectableList, event: chasen.Event) ?Msg {
        return self.list.handleEvent(event);
    }

    /// Draw the selectable list into a vertical region.
    pub fn view(self: *const SelectableList, surface: *chasen.Surface, opts: ViewOptions) void {
        var list_opts = opts;
        list_opts.selected_index = self.selectedIndex();
        self.list.view(surface, list_opts);
    }
};

fn clampedOptionalIndex(index: ?usize, len: usize) ?usize {
    const value = index orelse return null;
    if (len == 0 or value >= len) return null;
    return value;
}

test "SelectableList initializes focus and selected index" {
    const items = [_][]const u8{ "Alpha", "Beta" };
    const list = SelectableList.init(.{
        .items = &items,
        .selected_index = 1,
    });

    try std.testing.expectEqual(@as(usize, 0), list.focusedIndex());
    try std.testing.expectEqual(@as(?usize, 1), list.selectedIndex());
    try std.testing.expectEqualStrings("Beta", list.selectedLabel().?);
}

test "SelectableList ignores out of range selected index" {
    const items = [_][]const u8{"Alpha"};
    const list = SelectableList.init(.{
        .items = &items,
        .selected_index = 9,
    });

    try std.testing.expect(list.selectedIndex() == null);
    try std.testing.expect(list.selectedLabel() == null);
}

test "SelectableList update moves focus and stores activation" {
    const items = [_][]const u8{ "Alpha", "Beta" };
    var list = SelectableList.init(.{ .items = &items });

    list.update(.move_next);
    try std.testing.expectEqual(@as(usize, 1), list.focusedIndex());

    list.update(.{ .activate = list.focusedIndex() });
    try std.testing.expectEqual(@as(?usize, 1), list.selectedIndex());
    try std.testing.expectEqualStrings("Beta", list.selectedLabel().?);
}

test "SelectableList maps keyboard events through List" {
    const items = [_][]const u8{ "Alpha", "Beta" };
    var list = SelectableList.init(.{ .items = &items });

    try std.testing.expectEqual(SelectableList.Msg.move_next, list.handleEvent(.{
        .key_press = .{ .codepoint = chasen.Key.down },
    }).?);
    list.update(.move_next);
    try std.testing.expectEqual(SelectableList.Msg{ .activate = 1 }, list.handleEvent(.{
        .key_press = .{ .codepoint = '\r' },
    }).?);
}
