const std = @import("std");

/// Focus state for a fixed-length linear list.
///
/// `FocusList` is a state helper, not a component. It does not draw, handle
/// events, or route component messages. Applications use it to track which
/// sibling item currently has focus, then decide how to route events and render
/// focus indication.
///
/// The initial API is intended for fixed-length lists. Callers that use
/// `focused()` for component routing must guarantee `len > 0`.
pub const FocusList = struct {
    /// Currently focused index.
    index: usize = 0,
    /// Number of focusable items. The initial API assumes this is fixed.
    len: usize = 0,

    /// Create focus state for a fixed-length list.
    pub fn init(len: usize) FocusList {
        return .{ .len = len };
    }

    /// Return the currently focused index.
    ///
    /// When `len == 0`, this returns `0`. Callers must guarantee `len > 0`
    /// before using this value for component routing.
    pub fn focused(self: FocusList) usize {
        if (self.len == 0) return 0;
        return self.index;
    }

    /// Return whether `index` is currently focused.
    ///
    /// When `len == 0`, this always returns `false`.
    pub fn isFocused(self: FocusList, index: usize) bool {
        if (self.len == 0) return false;
        return self.index == index;
    }

    /// Move focus to the previous item, clamped at the first item.
    pub fn movePrev(self: *FocusList) void {
        if (self.len == 0) return;
        if (self.index > 0) self.index -= 1;
    }

    /// Move focus to the next item, clamped at the last item.
    pub fn moveNext(self: *FocusList) void {
        if (self.len == 0) return;
        if (self.index + 1 < self.len) self.index += 1;
    }
};

test "FocusList initializes at the first item" {
    const focus = FocusList.init(3);

    try std.testing.expectEqual(@as(usize, 0), focus.focused());
    try std.testing.expect(focus.isFocused(0));
    try std.testing.expect(!focus.isFocused(1));
}

test "FocusList moves next and previous" {
    var focus = FocusList.init(3);

    focus.moveNext();
    try std.testing.expectEqual(@as(usize, 1), focus.focused());

    focus.movePrev();
    try std.testing.expectEqual(@as(usize, 0), focus.focused());
}

test "FocusList clamps at boundaries" {
    var focus = FocusList.init(2);

    focus.movePrev();
    try std.testing.expectEqual(@as(usize, 0), focus.focused());

    focus.moveNext();
    focus.moveNext();
    try std.testing.expectEqual(@as(usize, 1), focus.focused());
}

test "FocusList handles empty lists as no-op" {
    var focus = FocusList.init(0);

    focus.movePrev();
    focus.moveNext();

    try std.testing.expectEqual(@as(usize, 0), focus.focused());
    try std.testing.expect(!focus.isFocused(0));
}
