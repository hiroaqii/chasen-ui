const std = @import("std");
const chasen = @import("chasen");

pub const FourStateStyles = struct {
    normal: chasen.TextStyle = .{},
    focused: chasen.TextStyle = .{},
    selected: chasen.TextStyle = .{},
    focused_selected: chasen.TextStyle = .{},
};

pub fn fourStateStyle(styles: FourStateStyles, focused: bool, selected: bool) chasen.TextStyle {
    if (focused and selected) return styles.focused_selected;
    if (focused) return styles.focused;
    if (selected) return styles.selected;
    return styles.normal;
}

pub fn clampedIndex(index: usize, len: usize) usize {
    if (len == 0) return 0;
    return @min(index, len - 1);
}

test "fourStateStyle chooses the matching state" {
    const styles = FourStateStyles{
        .normal = .{},
        .focused = .{ .bold = true },
        .selected = .{ .fg = .{ .index = 2 } },
        .focused_selected = .{ .bold = true, .fg = .{ .index = 3 } },
    };

    try std.testing.expect(!fourStateStyle(styles, false, false).bold);
    try std.testing.expect(fourStateStyle(styles, true, false).bold);
    try std.testing.expect(fourStateStyle(styles, false, true).fg.eql(.{ .index = 2 }));
    const both = fourStateStyle(styles, true, true);
    try std.testing.expect(both.bold);
    try std.testing.expect(both.fg.eql(.{ .index = 3 }));
}

test "clampedIndex handles empty and out-of-range lengths" {
    try std.testing.expectEqual(@as(usize, 0), clampedIndex(0, 0));
    try std.testing.expectEqual(@as(usize, 0), clampedIndex(99, 0));
    try std.testing.expectEqual(@as(usize, 0), clampedIndex(0, 3));
    try std.testing.expectEqual(@as(usize, 2), clampedIndex(99, 3));
}
