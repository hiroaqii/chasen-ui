const std = @import("std");
const chasen = @import("chasen");
const Viewport = @import("../viewport.zig").Viewport;
const list_component = @import("list.zig");
const nav_util = @import("nav_util.zig");

/// Stateless viewport helpers for `List`.
///
/// `ListViewport` does not own scroll state. It computes the visible range
/// needed to keep the focused item on screen and can render that range into the
/// provided surface. Apps still own item data, focus updates, selection policy,
/// and any animation-specific rendering.
pub const ListViewport = struct {
    /// Half-open visible range into the full item list.
    pub const Range = Viewport.Range;

    /// Return the visible item range needed to keep `focused_index` on screen.
    pub fn visibleRange(item_count: usize, focused_index: usize, visible_height: usize) Range {
        if (item_count == 0 or visible_height == 0) return .{ .start = 0, .end = 0 };

        const clamped_height = @min(visible_height, item_count);
        const start = Viewport.offsetKeepingIndexVisible(item_count, clamped_height, 0, focused_index);
        return Viewport.init(.{
            .total = item_count,
            .height = clamped_height,
            .offset = start,
        }).visibleRange();
    }

    /// Draw the visible range of `list` into `surface`.
    pub fn view(list: *const list_component.List, surface: *chasen.Surface, opts: list_component.List.ViewOptions) void {
        const size = surface.size();
        if (size.width == 0 or size.height == 0 or list.items.len == 0) return;

        const range = visibleRange(list.items.len, list.focusedIndex(), size.height);
        if (range.end <= range.start) return;

        const focused_index = list.focusedIndex();
        for (list.items[range.start..range.end], 0..) |item, local_index| {
            const global_index = range.start + local_index;
            const row: u16 = @intCast(local_index);
            const focused = global_index == focused_index;
            const selected = opts.selected_index != null and opts.selected_index.? == global_index;
            const marker = if (focused) opts.focused_marker else opts.marker;

            _ = surface.borrowTextAt(0, row, marker, opts.marker_style);
            if (size.width > 2) {
                _ = surface.borrowTextAt(2, row, item, nav_util.fourStateStyle(.{
                    .normal = opts.item_style,
                    .focused = opts.focused_style,
                    .selected = opts.selected_style,
                    .focused_selected = opts.focused_selected_style,
                }, focused, selected));
            }
        }

        if (opts.show_cursor and focused_index >= range.start and focused_index < range.end) {
            const cursor_row: u16 = @intCast(focused_index - range.start);
            surface.showCursor(@min(@as(u16, 2), size.width - 1), cursor_row);
        }
    }

    /// Format a one-based visible range summary such as `6-10/20`.
    pub fn positionText(allocator: std.mem.Allocator, range: Range, item_count: usize) ![]u8 {
        if (item_count == 0 or range.end <= range.start) {
            return try std.fmt.allocPrint(allocator, "0/{d}", .{item_count});
        }
        return try std.fmt.allocPrint(allocator, "{d}-{d}/{d}", .{ range.start + 1, range.end, item_count });
    }

    /// Format a one-based focused item summary such as `3/50`.
    pub fn focusedPositionText(allocator: std.mem.Allocator, focused_index: usize, item_count: usize) ![]u8 {
        if (item_count == 0) return try std.fmt.allocPrint(allocator, "0/0", .{});
        return try std.fmt.allocPrint(allocator, "{d}/{d}", .{ @min(focused_index, item_count - 1) + 1, item_count });
    }
};

test "ListViewport visible range keeps focused item in view" {
    try std.testing.expectEqual(ListViewport.Range{ .start = 0, .end = 0 }, ListViewport.visibleRange(0, 0, 5));
    try std.testing.expectEqual(ListViewport.Range{ .start = 0, .end = 0 }, ListViewport.visibleRange(10, 0, 0));
    try std.testing.expectEqual(ListViewport.Range{ .start = 0, .end = 3 }, ListViewport.visibleRange(3, 0, 10));
    try std.testing.expectEqual(ListViewport.Range{ .start = 0, .end = 5 }, ListViewport.visibleRange(10, 0, 5));
    try std.testing.expectEqual(ListViewport.Range{ .start = 1, .end = 6 }, ListViewport.visibleRange(10, 5, 5));
    try std.testing.expectEqual(ListViewport.Range{ .start = 5, .end = 10 }, ListViewport.visibleRange(10, 99, 5));
}

test {
    _ = nav_util;
}

test "ListViewport renders focused item inside the visible range" {
    const items = [_][]const u8{ "Alpha", "Beta", "Gamma", "Delta", "Epsilon" };
    var list = list_component.List.init(.{ .items = &items });
    list.update(.move_next);
    list.update(.move_next);
    list.update(.move_next);
    list.update(.move_next);

    var ts: chasen.testing.TestSurface = undefined;
    try ts.init(12, 3);
    defer ts.deinit();

    ListViewport.view(&list, &ts.surface, .{});

    try ts.expectCellText(2, 0, "G");
    try ts.expectCellText(2, 1, "D");
    try ts.expectCellText(0, 2, ">");
    try ts.expectCellText(2, 2, "E");
}

test "ListViewport position text uses one-based ranges" {
    const text = try ListViewport.positionText(std.testing.allocator, .{ .start = 5, .end = 10 }, 20);
    defer std.testing.allocator.free(text);

    try std.testing.expectEqualStrings("6-10/20", text);
}

test "ListViewport position text handles empty visible range" {
    const text = try ListViewport.positionText(std.testing.allocator, .{ .start = 0, .end = 0 }, 20);
    defer std.testing.allocator.free(text);

    try std.testing.expectEqualStrings("0/20", text);
}

test "ListViewport focused position text clamps out-of-range focus" {
    const text = try ListViewport.focusedPositionText(std.testing.allocator, 99, 3);
    defer std.testing.allocator.free(text);

    try std.testing.expectEqualStrings("3/3", text);
}
