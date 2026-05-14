const std = @import("std");
const chasen = @import("chasen");

/// Insets for shrinking a rectangle.
///
/// Insets are measured in terminal cells. Values that exceed the rectangle
/// size collapse the affected dimension to zero instead of underflowing.
pub const Insets = struct {
    top: u16 = 0,
    right: u16 = 0,
    bottom: u16 = 0,
    left: u16 = 0,

    /// Return the same inset on every side.
    pub fn all(value: u16) Insets {
        return .{
            .top = value,
            .right = value,
            .bottom = value,
            .left = value,
        };
    }

    /// Return vertical and horizontal inset pairs.
    pub fn axes(vertical: u16, horizontal: u16) Insets {
        return .{
            .top = vertical,
            .right = horizontal,
            .bottom = vertical,
            .left = horizontal,
        };
    }
};

/// A split segment.
///
/// `length` reserves a fixed number of cells. `fill` consumes a weighted share
/// of the remaining cells after fixed lengths are reserved. If both are set,
/// `length` wins so callers can build specs with a single struct shape.
pub const SplitSpec = struct {
    length: ?u16 = null,
    fill: u16 = 0,
};

/// Horizontal alignment within a rectangle.
pub const HorizontalAlign = enum {
    left,
    center,
    right,
};

/// Vertical alignment within a rectangle.
pub const VerticalAlign = enum {
    top,
    middle,
    bottom,
};

/// Two-axis alignment within a rectangle.
pub const Alignment = struct {
    horizontal: HorizontalAlign = .left,
    vertical: VerticalAlign = .top,

    pub const top_left: Alignment = .{ .horizontal = .left, .vertical = .top };
    pub const top_center: Alignment = .{ .horizontal = .center, .vertical = .top };
    pub const top_right: Alignment = .{ .horizontal = .right, .vertical = .top };
    pub const middle_left: Alignment = .{ .horizontal = .left, .vertical = .middle };
    pub const middle_center: Alignment = .{ .horizontal = .center, .vertical = .middle };
    pub const middle_right: Alignment = .{ .horizontal = .right, .vertical = .middle };
    pub const bottom_left: Alignment = .{ .horizontal = .left, .vertical = .bottom };
    pub const bottom_center: Alignment = .{ .horizontal = .center, .vertical = .bottom };
    pub const bottom_right: Alignment = .{ .horizontal = .right, .vertical = .bottom };
};

/// Options for stacking fixed-size rectangles vertically.
pub const StackOptions = struct {
    gap: u16 = 0,
    horizontal: HorizontalAlign = .left,
};

/// Return `rect` shrunk by `insets`.
pub fn inset(rect: chasen.Rect, insets: Insets) chasen.Rect {
    const horizontal = saturatingAdd(insets.left, insets.right);
    const vertical = saturatingAdd(insets.top, insets.bottom);
    const width = rect.width -| @min(rect.width, horizontal);
    const height = rect.height -| @min(rect.height, vertical);

    return .{
        .col = rect.col +| @min(rect.width, insets.left),
        .row = rect.row +| @min(rect.height, insets.top),
        .width = width,
        .height = height,
    };
}

/// Return a child rectangle of `size` aligned within `rect`.
///
/// Requested size is clamped to `rect`, so the result never exceeds the parent
/// rectangle. `alignRect` only calculates geometry; callers still decide whether to
/// create a child surface or pass the resulting fields into component options.
pub fn alignRect(rect: chasen.Rect, size: chasen.Size, alignment: Alignment) chasen.Rect {
    const width = @min(size.width, rect.width);
    const height = @min(size.height, rect.height);
    return .{
        .col = rect.col +| horizontalOffset(rect.width, width, alignment.horizontal),
        .row = rect.row +| verticalOffset(rect.height, height, alignment.vertical),
        .width = width,
        .height = height,
    };
}

/// Stack fixed-size child rectangles from top to bottom within `rect`.
///
/// Each requested size is clamped to the remaining parent height and parent
/// width. `gap` cells are skipped between returned rectangles.
pub fn stack(out: []chasen.Rect, rect: chasen.Rect, sizes: []const chasen.Size, opts: StackOptions) []chasen.Rect {
    const count = @min(out.len, sizes.len);
    var cursor: u16 = 0;

    for (out[0..count], sizes[0..count], 0..) |*slot, size, i| {
        const top = @min(rect.height, cursor);
        const available_height = rect.height - top;
        const height = @min(size.height, available_height);
        const width = @min(size.width, rect.width);
        const band = chasen.Rect{
            .col = rect.col,
            .row = rect.row +| top,
            .width = rect.width,
            .height = height,
        };

        slot.* = alignRect(band, .{ .width = width, .height = height }, .{
            .horizontal = opts.horizontal,
            .vertical = .top,
        });

        cursor = saturatingAdd(cursor, height);
        if (i + 1 < count) {
            cursor = saturatingAdd(cursor, opts.gap);
        }
    }

    return out[0..count];
}

/// Split `rect` into vertical bands.
///
/// Results are written into `out` and the returned slice is the portion filled.
/// If `out` is shorter than `specs`, only the first `out.len` specs are used.
pub fn splitVertical(out: []chasen.Rect, rect: chasen.Rect, specs: []const SplitSpec) []chasen.Rect {
    const count = @min(out.len, specs.len);
    split(out[0..count], rect, specs[0..count], .vertical);
    return out[0..count];
}

/// Split `rect` into horizontal bands.
///
/// Results are written into `out` and the returned slice is the portion filled.
/// If `out` is shorter than `specs`, only the first `out.len` specs are used.
pub fn splitHorizontal(out: []chasen.Rect, rect: chasen.Rect, specs: []const SplitSpec) []chasen.Rect {
    const count = @min(out.len, specs.len);
    split(out[0..count], rect, specs[0..count], .horizontal);
    return out[0..count];
}

const Direction = enum {
    vertical,
    horizontal,
};

fn split(out: []chasen.Rect, rect: chasen.Rect, specs: []const SplitSpec, direction: Direction) void {
    const total = switch (direction) {
        .vertical => rect.height,
        .horizontal => rect.width,
    };
    const plan = splitPlan(total, specs);

    var cursor: u16 = 0;
    var fill_extra = plan.fill_extra;

    for (out, specs) |*slot, spec| {
        const length = segmentLength(spec, plan.fill_space, plan.fill_weight, &fill_extra);
        const available = total -| cursor;
        const clamped_length = @min(length, available);

        slot.* = switch (direction) {
            .vertical => .{
                .col = rect.col,
                .row = rect.row +| cursor,
                .width = rect.width,
                .height = clamped_length,
            },
            .horizontal => .{
                .col = rect.col +| cursor,
                .row = rect.row,
                .width = clamped_length,
                .height = rect.height,
            },
        };

        cursor +|= clamped_length;
    }
}

const SplitPlan = struct {
    fill_space: u16,
    fill_weight: u32,
    fill_extra: u16,
};

fn splitPlan(total: u16, specs: []const SplitSpec) SplitPlan {
    var fixed: u16 = 0;
    var fill_weight: u32 = 0;

    for (specs) |spec| {
        if (spec.length) |length| {
            fixed = saturatingAdd(fixed, length);
        } else {
            fill_weight += spec.fill;
        }
    }

    const fixed_space = @min(fixed, total);
    const fill_space = total - fixed_space;
    const fill_extra = fillExtraCells(fill_space, fill_weight, specs);
    return .{
        .fill_space = fill_space,
        .fill_weight = fill_weight,
        .fill_extra = fill_extra,
    };
}

fn segmentLength(spec: SplitSpec, fill_space: u16, fill_weight: u32, fill_extra: *u16) u16 {
    if (spec.length) |length| return length;
    if (spec.fill == 0 or fill_weight == 0) return 0;

    const weighted = @as(u32, fill_space) * @as(u32, spec.fill);
    var length: u16 = @intCast(weighted / fill_weight);
    if (fill_extra.* > 0) {
        length +|= 1;
        fill_extra.* -= 1;
    }
    return length;
}

fn fillExtraCells(fill_space: u16, fill_weight: u32, specs: []const SplitSpec) u16 {
    if (fill_weight == 0) return 0;

    var base_sum: u16 = 0;
    for (specs) |spec| {
        if (spec.length != null or spec.fill == 0) continue;

        const weighted = @as(u32, fill_space) * @as(u32, spec.fill);
        base_sum +|= @intCast(weighted / fill_weight);
    }

    return fill_space -| @min(fill_space, base_sum);
}

fn saturatingAdd(a: u16, b: u16) u16 {
    return a +| b;
}

fn horizontalOffset(parent_width: u16, child_width: u16, alignment: HorizontalAlign) u16 {
    const remaining = parent_width -| @min(parent_width, child_width);
    return switch (alignment) {
        .left => 0,
        .center => remaining / 2,
        .right => remaining,
    };
}

fn verticalOffset(parent_height: u16, child_height: u16, alignment: VerticalAlign) u16 {
    const remaining = parent_height -| @min(parent_height, child_height);
    return switch (alignment) {
        .top => 0,
        .middle => remaining / 2,
        .bottom => remaining,
    };
}

test "Insets constructors build common values" {
    try std.testing.expectEqual(Insets{ .top = 2, .right = 2, .bottom = 2, .left = 2 }, Insets.all(2));
    try std.testing.expectEqual(Insets{ .top = 1, .right = 3, .bottom = 1, .left = 3 }, Insets.axes(1, 3));
}

test "inset shrinks a rect" {
    const rect: chasen.Rect = .{ .col = 2, .row = 3, .width = 10, .height = 6 };

    try std.testing.expectEqual(chasen.Rect{
        .col = 4,
        .row = 4,
        .width = 5,
        .height = 3,
    }, inset(rect, .{ .top = 1, .right = 3, .bottom = 2, .left = 2 }));
}

test "inset collapses when insets exceed size" {
    const rect: chasen.Rect = .{ .col = 2, .row = 3, .width = 4, .height = 2 };

    try std.testing.expectEqual(chasen.Rect{
        .col = 6,
        .row = 5,
        .width = 0,
        .height = 0,
    }, inset(rect, Insets.all(9)));
}

test "align positions a child rectangle inside a parent" {
    const rect: chasen.Rect = .{ .col = 2, .row = 3, .width = 10, .height = 6 };

    try std.testing.expectEqual(chasen.Rect{
        .col = 5,
        .row = 5,
        .width = 4,
        .height = 2,
    }, alignRect(rect, .{ .width = 4, .height = 2 }, .middle_center));

    try std.testing.expectEqual(chasen.Rect{
        .col = 8,
        .row = 7,
        .width = 4,
        .height = 2,
    }, alignRect(rect, .{ .width = 4, .height = 2 }, .bottom_right));
}

test "align clamps child size to parent size" {
    const rect: chasen.Rect = .{ .col = 2, .row = 3, .width = 4, .height = 2 };

    try std.testing.expectEqual(chasen.Rect{
        .col = 2,
        .row = 3,
        .width = 4,
        .height = 2,
    }, alignRect(rect, .{ .width = 10, .height = 8 }, .bottom_right));
}

test "stack positions fixed-size rectangles with gaps" {
    const rect: chasen.Rect = .{ .col = 2, .row = 3, .width = 10, .height = 8 };
    var areas: [3]chasen.Rect = undefined;
    const result = stack(&areas, rect, &.{
        .{ .width = 4, .height = 1 },
        .{ .width = 6, .height = 2 },
        .{ .width = 3, .height = 1 },
    }, .{
        .gap = 1,
        .horizontal = .center,
    });

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(chasen.Rect{ .col = 5, .row = 3, .width = 4, .height = 1 }, result[0]);
    try std.testing.expectEqual(chasen.Rect{ .col = 4, .row = 5, .width = 6, .height = 2 }, result[1]);
    try std.testing.expectEqual(chasen.Rect{ .col = 5, .row = 8, .width = 3, .height = 1 }, result[2]);
}

test "stack clamps to parent width and remaining height" {
    const rect: chasen.Rect = .{ .col = 2, .row = 3, .width = 5, .height = 3 };
    var areas: [2]chasen.Rect = undefined;
    const result = stack(&areas, rect, &.{
        .{ .width = 9, .height = 2 },
        .{ .width = 4, .height = 4 },
    }, .{ .gap = 1 });

    try std.testing.expectEqual(@as(usize, 2), result.len);
    try std.testing.expectEqual(chasen.Rect{ .col = 2, .row = 3, .width = 5, .height = 2 }, result[0]);
    try std.testing.expectEqual(chasen.Rect{ .col = 2, .row = 6, .width = 4, .height = 0 }, result[1]);
}

test "splitVertical handles fixed and fill segments" {
    const rect: chasen.Rect = .{ .col = 1, .row = 2, .width = 10, .height = 9 };
    var areas: [3]chasen.Rect = undefined;
    const result = splitVertical(&areas, rect, &.{
        .{ .length = 2 },
        .{ .fill = 1 },
        .{ .length = 3 },
    });

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(chasen.Rect{ .col = 1, .row = 2, .width = 10, .height = 2 }, result[0]);
    try std.testing.expectEqual(chasen.Rect{ .col = 1, .row = 4, .width = 10, .height = 4 }, result[1]);
    try std.testing.expectEqual(chasen.Rect{ .col = 1, .row = 8, .width = 10, .height = 3 }, result[2]);
}

test "splitHorizontal distributes fill remainder to earlier fill segments" {
    const rect: chasen.Rect = .{ .col = 0, .row = 0, .width = 7, .height = 3 };
    var areas: [3]chasen.Rect = undefined;
    const result = splitHorizontal(&areas, rect, &.{
        .{ .fill = 1 },
        .{ .fill = 1 },
        .{ .fill = 1 },
    });

    try std.testing.expectEqual(chasen.Rect{ .col = 0, .row = 0, .width = 3, .height = 3 }, result[0]);
    try std.testing.expectEqual(chasen.Rect{ .col = 3, .row = 0, .width = 2, .height = 3 }, result[1]);
    try std.testing.expectEqual(chasen.Rect{ .col = 5, .row = 0, .width = 2, .height = 3 }, result[2]);
}

test "splitHorizontal keeps weighted fill segments within total width" {
    const rect: chasen.Rect = .{ .col = 0, .row = 0, .width = 5, .height = 3 };
    var areas: [2]chasen.Rect = undefined;
    const result = splitHorizontal(&areas, rect, &.{
        .{ .fill = 2 },
        .{ .fill = 1 },
    });

    try std.testing.expectEqual(chasen.Rect{ .col = 0, .row = 0, .width = 4, .height = 3 }, result[0]);
    try std.testing.expectEqual(chasen.Rect{ .col = 4, .row = 0, .width = 1, .height = 3 }, result[1]);
}

test "split clamps fixed segments when they exceed available space" {
    const rect: chasen.Rect = .{ .col = 0, .row = 0, .width = 5, .height = 3 };
    var areas: [2]chasen.Rect = undefined;
    const result = splitVertical(&areas, rect, &.{
        .{ .length = 2 },
        .{ .length = 5 },
    });

    try std.testing.expectEqual(chasen.Rect{ .col = 0, .row = 0, .width = 5, .height = 2 }, result[0]);
    try std.testing.expectEqual(chasen.Rect{ .col = 0, .row = 2, .width = 5, .height = 1 }, result[1]);
}

test "split returns only the output capacity" {
    const rect: chasen.Rect = .{ .col = 0, .row = 0, .width = 5, .height = 3 };
    var areas: [1]chasen.Rect = undefined;
    const result = splitVertical(&areas, rect, &.{
        .{ .length = 1 },
        .{ .length = 1 },
    });

    try std.testing.expectEqual(@as(usize, 1), result.len);
    try std.testing.expectEqual(chasen.Rect{ .col = 0, .row = 0, .width = 5, .height = 1 }, result[0]);
}
