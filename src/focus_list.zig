const std = @import("std");

/// Focus state for a fixed-length linear list of sibling items.
///
/// `FocusList` is a state helper, not a component. It does not draw, handle
/// events, or route component messages. Applications use it to track which
/// sibling item currently has focus, then decide how to route events and render
/// focus indication.
///
/// The initial API is intentionally small:
///
/// - the list length is fixed after `init`
/// - movement clamps at the first and last item
/// - hidden, disabled, nested, and wrapping focus policies stay in the app
///
/// This keeps focus ownership explicit in Elm-style apps. App code handles
/// navigation keys, mutates `FocusList`, wraps component messages in app
/// messages, and passes focus state to component `view` options.
///
/// Callers that use `focused()` for component routing must guarantee `len > 0`.
pub const FocusList = struct {
    /// Currently focused index.
    ///
    /// This value is always intended to be less than `len` when `len > 0`.
    /// For `len == 0`, navigation is a no-op and `focused()` returns `0`.
    index: usize = 0,
    /// Number of focusable items.
    ///
    /// The initial API assumes this is fixed. If a caller changes `len`
    /// manually, it must also keep `index` valid for the new length.
    len: usize = 0,

    /// Create focus state for a fixed-length list.
    ///
    /// Focus starts at index `0`. For an empty list, movement methods are
    /// no-ops and `isFocused` always returns `false`.
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

    /// Return whether the given item index is currently focused.
    ///
    /// When `len == 0`, this always returns `false`.
    pub fn isFocused(self: FocusList, index: usize) bool {
        if (self.len == 0) return false;
        return self.index == index;
    }

    /// Move focus to the previous item.
    ///
    /// Movement is clamped: calling this at the first item keeps focus at the
    /// first item. For an empty list, this is a no-op.
    pub fn movePrev(self: *FocusList) void {
        if (self.len == 0) return;
        if (self.index > 0) self.index -= 1;
    }

    /// Move focus to the next item.
    ///
    /// Movement is clamped: calling this at the last item keeps focus at the
    /// last item. For an empty list, this is a no-op.
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
