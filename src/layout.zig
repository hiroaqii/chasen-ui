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

/// Options for laying out fixed-size rectangles horizontally.
pub const RowOptions = struct {
    gap: u16 = 0,
    vertical: VerticalAlign = .top,
};

/// Options for splitting a rectangle into equal-width columns.
pub const ColumnsOptions = struct {
    /// Cells skipped between adjacent columns before the remaining width is divided.
    gap: u16 = 0,
};

/// Options for splitting a rectangle into equal-height rows.
pub const RowsOptions = struct {
    /// Cells skipped between adjacent rows before the remaining height is divided.
    gap: u16 = 0,
};

/// Options for splitting a rectangle into a fixed row-major grid.
pub const FixedGridOptions = struct {
    /// Number of cells on the horizontal axis.
    columns: u16,
    /// Number of cells on the vertical axis.
    rows: u16,
    /// Cells skipped between adjacent columns before column widths are divided.
    column_gap: u16 = 0,
    /// Cells skipped between adjacent rows before row heights are divided.
    row_gap: u16 = 0,
};

/// Result of taking one edge band from a rectangle.
pub const TakeResult = struct {
    /// The requested edge band, clamped to the parent rectangle.
    taken: chasen.Rect,
    /// The remaining rectangle after `taken` is removed.
    rest: chasen.Rect,
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

/// Take a band from the top edge of `rect`.
///
/// `height` is clamped to `rect.height`, so the result never underflows. Use
/// `rest` for the body area after reserving a header.
pub fn takeTop(rect: chasen.Rect, height: u16) TakeResult {
    const taken_height = @min(height, rect.height);
    return .{
        .taken = .{
            .col = rect.col,
            .row = rect.row,
            .width = rect.width,
            .height = taken_height,
        },
        .rest = .{
            .col = rect.col,
            .row = rect.row +| taken_height,
            .width = rect.width,
            .height = rect.height - taken_height,
        },
    };
}

/// Take a band from the bottom edge of `rect`.
///
/// `height` is clamped to `rect.height`, so the result never underflows. Use
/// `rest` for the body area above a footer.
pub fn takeBottom(rect: chasen.Rect, height: u16) TakeResult {
    const taken_height = @min(height, rect.height);
    const rest_height = rect.height - taken_height;
    return .{
        .taken = .{
            .col = rect.col,
            .row = rect.row +| rest_height,
            .width = rect.width,
            .height = taken_height,
        },
        .rest = .{
            .col = rect.col,
            .row = rect.row,
            .width = rect.width,
            .height = rest_height,
        },
    };
}

/// Take a band from the left edge of `rect`.
///
/// `width` is clamped to `rect.width`, so the result never underflows. Use
/// `rest` for the body area after reserving a sidebar.
pub fn takeLeft(rect: chasen.Rect, width: u16) TakeResult {
    const taken_width = @min(width, rect.width);
    return .{
        .taken = .{
            .col = rect.col,
            .row = rect.row,
            .width = taken_width,
            .height = rect.height,
        },
        .rest = .{
            .col = rect.col +| taken_width,
            .row = rect.row,
            .width = rect.width - taken_width,
            .height = rect.height,
        },
    };
}

/// Take a band from the right edge of `rect`.
///
/// `width` is clamped to `rect.width`, so the result never underflows. Use
/// `rest` for the body area before a right-side inspector.
pub fn takeRight(rect: chasen.Rect, width: u16) TakeResult {
    const taken_width = @min(width, rect.width);
    const rest_width = rect.width - taken_width;
    return .{
        .taken = .{
            .col = rect.col +| rest_width,
            .row = rect.row,
            .width = taken_width,
            .height = rect.height,
        },
        .rest = .{
            .col = rect.col,
            .row = rect.row,
            .width = rest_width,
            .height = rect.height,
        },
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

/// Return a child rectangle of `size` centered within `rect`.
///
/// This is a convenience wrapper around `alignRect(rect, size, .middle_center)`.
pub fn center(rect: chasen.Rect, size: chasen.Size) chasen.Rect {
    return alignRect(rect, size, .middle_center);
}

/// Return `size` clamped to `max`.
pub fn maxSize(size: chasen.Size, max: chasen.Size) chasen.Size {
    return .{
        .width = @min(size.width, max.width),
        .height = @min(size.height, max.height),
    };
}

/// Return `rect` with its size clamped to `max`.
///
/// Position is preserved. Use `center(rect, max_size)` when the constrained
/// child rectangle should be centered inside the parent instead.
pub fn constrain(rect: chasen.Rect, max: chasen.Size) chasen.Rect {
    const size = maxSize(.{ .width = rect.width, .height = rect.height }, max);
    return .{
        .col = rect.col,
        .row = rect.row,
        .width = size.width,
        .height = size.height,
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

/// Lay out fixed-size child rectangles from left to right within `rect`.
///
/// Each requested size is clamped to the remaining parent width and parent
/// height. `gap` cells are skipped between returned rectangles.
pub fn row(out: []chasen.Rect, rect: chasen.Rect, sizes: []const chasen.Size, opts: RowOptions) []chasen.Rect {
    const count = @min(out.len, sizes.len);
    var cursor: u16 = 0;

    for (out[0..count], sizes[0..count], 0..) |*slot, size, i| {
        const left = @min(rect.width, cursor);
        const available_width = rect.width - left;
        const width = @min(size.width, available_width);
        const height = @min(size.height, rect.height);
        const band = chasen.Rect{
            .col = rect.col +| left,
            .row = rect.row,
            .width = width,
            .height = rect.height,
        };

        slot.* = alignRect(band, .{ .width = width, .height = height }, .{
            .horizontal = .left,
            .vertical = opts.vertical,
        });

        cursor = saturatingAdd(cursor, width);
        if (i + 1 < count) {
            cursor = saturatingAdd(cursor, opts.gap);
        }
    }

    return out[0..count];
}

/// Split `rect` into equal-width columns.
///
/// The number of returned columns is `out.len`. `gap` cells are reserved
/// between columns before the remaining width is distributed. Extra cells from
/// uneven division are assigned to earlier columns.
pub fn columns(out: []chasen.Rect, rect: chasen.Rect, opts: ColumnsOptions) []chasen.Rect {
    divideEven(out, rect, opts.gap, .horizontal);
    return out;
}

/// Split `rect` into equal-height rows.
///
/// The number of returned rows is `out.len`. `gap` cells are reserved between
/// rows before the remaining height is distributed. Extra cells from uneven
/// division are assigned to earlier rows.
pub fn rows(out: []chasen.Rect, rect: chasen.Rect, opts: RowsOptions) []chasen.Rect {
    divideEven(out, rect, opts.gap, .vertical);
    return out;
}

/// Split `rect` into a fixed row-major grid.
///
/// The returned slice is capped by `out.len` and by `columns * rows`.
/// `columns == 0` or `rows == 0` returns an empty slice. Gaps are reserved
/// before each axis is evenly divided. Extra cells from uneven division are
/// assigned to earlier columns and rows.
pub fn fixedGrid(out: []chasen.Rect, rect: chasen.Rect, opts: FixedGridOptions) []chasen.Rect {
    if (opts.columns == 0 or opts.rows == 0 or out.len == 0) return out[0..0];

    const cell_count = @as(usize, opts.columns) * @as(usize, opts.rows);
    const count = @min(out.len, cell_count);
    const column_plan = evenPlan(rect.width, opts.column_gap, opts.columns);
    const row_plan = evenPlan(rect.height, opts.row_gap, opts.rows);

    for (out[0..count], 0..) |*slot, index| {
        const columns_count = @as(usize, opts.columns);
        const grid_row: u16 = @intCast(index / columns_count);
        const grid_col: u16 = @intCast(index % columns_count);
        const column_band = evenBand(column_plan, grid_col);
        const row_band = evenBand(row_plan, grid_row);

        slot.* = .{
            .col = rect.col +| column_band.start,
            .row = rect.row +| row_band.start,
            .width = column_band.length,
            .height = row_band.length,
        };
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

fn divideEven(out: []chasen.Rect, rect: chasen.Rect, gap: u16, direction: Direction) void {
    if (out.len == 0) return;

    const total = switch (direction) {
        .vertical => rect.height,
        .horizontal => rect.width,
    };
    const count: u16 = @intCast(@min(out.len, @as(usize, std.math.maxInt(u16))));
    const plan = evenPlan(total, gap, count);

    for (out, 0..) |*slot, index| {
        const band_index: u16 = @intCast(@min(index, @as(usize, count - 1)));
        const band = evenBand(plan, band_index);

        slot.* = switch (direction) {
            .vertical => .{
                .col = rect.col,
                .row = rect.row +| band.start,
                .width = rect.width,
                .height = band.length,
            },
            .horizontal => .{
                .col = rect.col +| band.start,
                .row = rect.row,
                .width = band.length,
                .height = rect.height,
            },
        };
    }
}

fn gapTotal(gap: u16, count: usize) u16 {
    var total: u16 = 0;
    var index: usize = 0;
    while (index < count) : (index += 1) {
        total = saturatingAdd(total, gap);
    }
    return total;
}

const EvenPlan = struct {
    total: u16,
    gap: u16,
    count: u16,
    base: u16,
    extra: u16,
};

const EvenBand = struct {
    start: u16,
    length: u16,
};

fn evenPlan(total: u16, gap: u16, count: u16) EvenPlan {
    if (count == 0) {
        return .{ .total = total, .gap = gap, .count = 0, .base = 0, .extra = 0 };
    }

    const gaps = gapTotal(gap, @as(usize, count - 1));
    const content_total = total -| @min(total, gaps);
    const base = content_total / count;
    const extra = content_total - (base * count);

    return .{
        .total = total,
        .gap = gap,
        .count = count,
        .base = base,
        .extra = extra,
    };
}

fn evenBand(plan: EvenPlan, index: u16) EvenBand {
    if (plan.count == 0) return .{ .start = 0, .length = 0 };

    const clamped_index = @min(index, plan.count - 1);
    const extra_before = @min(clamped_index, plan.extra);
    const start = saturatingAdd(clamped_index *| plan.base, extra_before) +| (clamped_index *| plan.gap);
    const length = plan.base + @as(u16, if (clamped_index < plan.extra) 1 else 0);
    const clamped_start = @min(plan.total, start);
    const available = plan.total - clamped_start;

    return .{
        .start = clamped_start,
        .length = @min(length, available),
    };
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
            fill_weight +|= spec.fill;
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

/// Return the horizontal offset for a child width aligned inside a parent width.
pub fn horizontalOffset(parent_width: u16, child_width: u16, alignment: HorizontalAlign) u16 {
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

test "takeTop returns a top band and remaining body" {
    const rect: chasen.Rect = .{ .col = 2, .row = 3, .width = 10, .height = 6 };
    const result = takeTop(rect, 2);

    try std.testing.expectEqual(chasen.Rect{ .col = 2, .row = 3, .width = 10, .height = 2 }, result.taken);
    try std.testing.expectEqual(chasen.Rect{ .col = 2, .row = 5, .width = 10, .height = 4 }, result.rest);
}

test "takeBottom returns a bottom band and remaining body" {
    const rect: chasen.Rect = .{ .col = 2, .row = 3, .width = 10, .height = 6 };
    const result = takeBottom(rect, 2);

    try std.testing.expectEqual(chasen.Rect{ .col = 2, .row = 7, .width = 10, .height = 2 }, result.taken);
    try std.testing.expectEqual(chasen.Rect{ .col = 2, .row = 3, .width = 10, .height = 4 }, result.rest);
}

test "takeLeft returns a left band and remaining body" {
    const rect: chasen.Rect = .{ .col = 2, .row = 3, .width = 10, .height = 6 };
    const result = takeLeft(rect, 3);

    try std.testing.expectEqual(chasen.Rect{ .col = 2, .row = 3, .width = 3, .height = 6 }, result.taken);
    try std.testing.expectEqual(chasen.Rect{ .col = 5, .row = 3, .width = 7, .height = 6 }, result.rest);
}

test "takeRight returns a right band and remaining body" {
    const rect: chasen.Rect = .{ .col = 2, .row = 3, .width = 10, .height = 6 };
    const result = takeRight(rect, 3);

    try std.testing.expectEqual(chasen.Rect{ .col = 9, .row = 3, .width = 3, .height = 6 }, result.taken);
    try std.testing.expectEqual(chasen.Rect{ .col = 2, .row = 3, .width = 7, .height = 6 }, result.rest);
}

test "take helpers clamp oversized requests" {
    const rect: chasen.Rect = .{ .col = 2, .row = 3, .width = 4, .height = 2 };

    try std.testing.expectEqual(TakeResult{
        .taken = .{ .col = 2, .row = 3, .width = 4, .height = 2 },
        .rest = .{ .col = 2, .row = 5, .width = 4, .height = 0 },
    }, takeTop(rect, 9));

    try std.testing.expectEqual(TakeResult{
        .taken = .{ .col = 2, .row = 3, .width = 4, .height = 2 },
        .rest = .{ .col = 6, .row = 3, .width = 0, .height = 2 },
    }, takeLeft(rect, 9));
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

test "horizontalOffset aligns child width within parent width" {
    try std.testing.expectEqual(@as(u16, 0), horizontalOffset(10, 4, .left));
    try std.testing.expectEqual(@as(u16, 3), horizontalOffset(10, 4, .center));
    try std.testing.expectEqual(@as(u16, 6), horizontalOffset(10, 4, .right));
}

test "horizontalOffset returns zero when child is at least parent width" {
    try std.testing.expectEqual(@as(u16, 0), horizontalOffset(4, 4, .right));
    try std.testing.expectEqual(@as(u16, 0), horizontalOffset(4, 8, .center));
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

test "center returns a middle-centered child rectangle" {
    const rect: chasen.Rect = .{ .col = 2, .row = 3, .width = 10, .height = 6 };

    try std.testing.expectEqual(chasen.Rect{
        .col = 5,
        .row = 5,
        .width = 4,
        .height = 2,
    }, center(rect, .{ .width = 4, .height = 2 }));
}

test "center clamps child size to parent size" {
    const rect: chasen.Rect = .{ .col = 2, .row = 3, .width = 4, .height = 2 };

    try std.testing.expectEqual(chasen.Rect{
        .col = 2,
        .row = 3,
        .width = 4,
        .height = 2,
    }, center(rect, .{ .width = 10, .height = 8 }));
}

test "maxSize clamps width and height independently" {
    try std.testing.expectEqual(chasen.Size{
        .width = 8,
        .height = 4,
    }, maxSize(.{ .width = 12, .height = 4 }, .{ .width = 8, .height = 6 }));
}

test "constrain preserves position and clamps size" {
    const rect: chasen.Rect = .{ .col = 2, .row = 3, .width = 10, .height = 6 };

    try std.testing.expectEqual(chasen.Rect{
        .col = 2,
        .row = 3,
        .width = 7,
        .height = 4,
    }, constrain(rect, .{ .width = 7, .height = 4 }));
}

test "center can be used for max-size centered rectangles" {
    const rect: chasen.Rect = .{ .col = 2, .row = 3, .width = 10, .height = 6 };

    try std.testing.expectEqual(chasen.Rect{
        .col = 4,
        .row = 4,
        .width = 6,
        .height = 4,
    }, center(rect, .{ .width = 6, .height = 4 }));
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

test "row positions fixed-size rectangles with gaps" {
    const rect: chasen.Rect = .{ .col = 2, .row = 3, .width = 12, .height = 6 };
    var areas: [3]chasen.Rect = undefined;
    const result = row(&areas, rect, &.{
        .{ .width = 4, .height = 2 },
        .{ .width = 2, .height = 4 },
        .{ .width = 3, .height = 1 },
    }, .{
        .gap = 1,
        .vertical = .middle,
    });

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(chasen.Rect{ .col = 2, .row = 5, .width = 4, .height = 2 }, result[0]);
    try std.testing.expectEqual(chasen.Rect{ .col = 7, .row = 4, .width = 2, .height = 4 }, result[1]);
    try std.testing.expectEqual(chasen.Rect{ .col = 10, .row = 5, .width = 3, .height = 1 }, result[2]);
}

test "row clamps to parent height and remaining width" {
    const rect: chasen.Rect = .{ .col = 2, .row = 3, .width = 5, .height = 3 };
    var areas: [2]chasen.Rect = undefined;
    const result = row(&areas, rect, &.{
        .{ .width = 3, .height = 9 },
        .{ .width = 4, .height = 2 },
    }, .{ .gap = 2 });

    try std.testing.expectEqual(@as(usize, 2), result.len);
    try std.testing.expectEqual(chasen.Rect{ .col = 2, .row = 3, .width = 3, .height = 3 }, result[0]);
    try std.testing.expectEqual(chasen.Rect{ .col = 7, .row = 3, .width = 0, .height = 2 }, result[1]);
}

test "columns split width evenly and distribute remainder" {
    const rect: chasen.Rect = .{ .col = 2, .row = 3, .width = 10, .height = 4 };
    var areas: [3]chasen.Rect = undefined;
    const result = columns(&areas, rect, .{});

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(chasen.Rect{ .col = 2, .row = 3, .width = 4, .height = 4 }, result[0]);
    try std.testing.expectEqual(chasen.Rect{ .col = 6, .row = 3, .width = 3, .height = 4 }, result[1]);
    try std.testing.expectEqual(chasen.Rect{ .col = 9, .row = 3, .width = 3, .height = 4 }, result[2]);
}

test "columns reserve gaps before splitting width" {
    const rect: chasen.Rect = .{ .col = 1, .row = 2, .width = 12, .height = 3 };
    var areas: [3]chasen.Rect = undefined;
    const result = columns(&areas, rect, .{ .gap = 1 });

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(chasen.Rect{ .col = 1, .row = 2, .width = 4, .height = 3 }, result[0]);
    try std.testing.expectEqual(chasen.Rect{ .col = 6, .row = 2, .width = 3, .height = 3 }, result[1]);
    try std.testing.expectEqual(chasen.Rect{ .col = 10, .row = 2, .width = 3, .height = 3 }, result[2]);
}

test "rows split height evenly and distribute remainder" {
    const rect: chasen.Rect = .{ .col = 2, .row = 3, .width = 8, .height = 7 };
    var areas: [3]chasen.Rect = undefined;
    const result = rows(&areas, rect, .{});

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(chasen.Rect{ .col = 2, .row = 3, .width = 8, .height = 3 }, result[0]);
    try std.testing.expectEqual(chasen.Rect{ .col = 2, .row = 6, .width = 8, .height = 2 }, result[1]);
    try std.testing.expectEqual(chasen.Rect{ .col = 2, .row = 8, .width = 8, .height = 2 }, result[2]);
}

test "rows reserve gaps before splitting height" {
    const rect: chasen.Rect = .{ .col = 1, .row = 2, .width = 8, .height = 9 };
    var areas: [3]chasen.Rect = undefined;
    const result = rows(&areas, rect, .{ .gap = 1 });

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(chasen.Rect{ .col = 1, .row = 2, .width = 8, .height = 3 }, result[0]);
    try std.testing.expectEqual(chasen.Rect{ .col = 1, .row = 6, .width = 8, .height = 2 }, result[1]);
    try std.testing.expectEqual(chasen.Rect{ .col = 1, .row = 9, .width = 8, .height = 2 }, result[2]);
}

test "columns collapse content when gaps exceed width" {
    const rect: chasen.Rect = .{ .col = 2, .row = 3, .width = 2, .height = 4 };
    var areas: [3]chasen.Rect = undefined;
    const result = columns(&areas, rect, .{ .gap = 2 });

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(chasen.Rect{ .col = 2, .row = 3, .width = 0, .height = 4 }, result[0]);
    try std.testing.expectEqual(chasen.Rect{ .col = 4, .row = 3, .width = 0, .height = 4 }, result[1]);
    try std.testing.expectEqual(chasen.Rect{ .col = 4, .row = 3, .width = 0, .height = 4 }, result[2]);
}

test "fixedGrid returns row-major equal cells" {
    const rect: chasen.Rect = .{ .col = 2, .row = 3, .width = 10, .height = 7 };
    var areas: [6]chasen.Rect = undefined;
    const result = fixedGrid(&areas, rect, .{ .columns = 3, .rows = 2 });

    try std.testing.expectEqual(@as(usize, 6), result.len);
    try std.testing.expectEqual(chasen.Rect{ .col = 2, .row = 3, .width = 4, .height = 4 }, result[0]);
    try std.testing.expectEqual(chasen.Rect{ .col = 6, .row = 3, .width = 3, .height = 4 }, result[1]);
    try std.testing.expectEqual(chasen.Rect{ .col = 9, .row = 3, .width = 3, .height = 4 }, result[2]);
    try std.testing.expectEqual(chasen.Rect{ .col = 2, .row = 7, .width = 4, .height = 3 }, result[3]);
    try std.testing.expectEqual(chasen.Rect{ .col = 6, .row = 7, .width = 3, .height = 3 }, result[4]);
    try std.testing.expectEqual(chasen.Rect{ .col = 9, .row = 7, .width = 3, .height = 3 }, result[5]);
}

test "fixedGrid reserves column and row gaps" {
    const rect: chasen.Rect = .{ .col = 1, .row = 2, .width = 12, .height = 8 };
    var areas: [4]chasen.Rect = undefined;
    const result = fixedGrid(&areas, rect, .{ .columns = 2, .rows = 2, .column_gap = 1, .row_gap = 1 });

    try std.testing.expectEqual(@as(usize, 4), result.len);
    try std.testing.expectEqual(chasen.Rect{ .col = 1, .row = 2, .width = 6, .height = 4 }, result[0]);
    try std.testing.expectEqual(chasen.Rect{ .col = 8, .row = 2, .width = 5, .height = 4 }, result[1]);
    try std.testing.expectEqual(chasen.Rect{ .col = 1, .row = 7, .width = 6, .height = 3 }, result[2]);
    try std.testing.expectEqual(chasen.Rect{ .col = 8, .row = 7, .width = 5, .height = 3 }, result[3]);
}

test "fixedGrid returns only output capacity" {
    const rect: chasen.Rect = .{ .col = 0, .row = 0, .width = 8, .height = 4 };
    var areas: [3]chasen.Rect = undefined;
    const result = fixedGrid(&areas, rect, .{ .columns = 2, .rows = 2 });

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(chasen.Rect{ .col = 0, .row = 0, .width = 4, .height = 2 }, result[0]);
    try std.testing.expectEqual(chasen.Rect{ .col = 4, .row = 0, .width = 4, .height = 2 }, result[1]);
    try std.testing.expectEqual(chasen.Rect{ .col = 0, .row = 2, .width = 4, .height = 2 }, result[2]);
}

test "fixedGrid returns empty for zero rows or columns" {
    const rect: chasen.Rect = .{ .col = 0, .row = 0, .width = 8, .height = 4 };
    var areas: [2]chasen.Rect = undefined;

    try std.testing.expectEqual(@as(usize, 0), fixedGrid(&areas, rect, .{ .columns = 0, .rows = 2 }).len);
    try std.testing.expectEqual(@as(usize, 0), fixedGrid(&areas, rect, .{ .columns = 2, .rows = 0 }).len);
}

test "fixedGrid collapses cells when gaps exceed size" {
    const rect: chasen.Rect = .{ .col = 2, .row = 3, .width = 2, .height = 1 };
    var areas: [4]chasen.Rect = undefined;
    const result = fixedGrid(&areas, rect, .{ .columns = 2, .rows = 2, .column_gap = 3, .row_gap = 2 });

    try std.testing.expectEqual(@as(usize, 4), result.len);
    try std.testing.expectEqual(chasen.Rect{ .col = 2, .row = 3, .width = 0, .height = 0 }, result[0]);
    try std.testing.expectEqual(chasen.Rect{ .col = 4, .row = 3, .width = 0, .height = 0 }, result[1]);
    try std.testing.expectEqual(chasen.Rect{ .col = 2, .row = 4, .width = 0, .height = 0 }, result[2]);
    try std.testing.expectEqual(chasen.Rect{ .col = 4, .row = 4, .width = 0, .height = 0 }, result[3]);
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

test "splitPlan saturates excessive fill weight" {
    const spec_count = 70_000;
    const specs = try std.testing.allocator.alloc(SplitSpec, spec_count);
    defer std.testing.allocator.free(specs);

    @memset(specs, SplitSpec{ .fill = std.math.maxInt(u16) });

    const plan = splitPlan(std.math.maxInt(u16), specs);

    try std.testing.expectEqual(std.math.maxInt(u32), plan.fill_weight);
    try std.testing.expect(plan.fill_space <= std.math.maxInt(u16));
    try std.testing.expect(plan.fill_extra <= plan.fill_space);
}
