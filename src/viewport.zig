const std = @import("std");

/// A scroll viewport over a fixed-size item or line collection.
///
/// `Viewport` is an allocation-free calculation helper. It does not own scroll
/// state, render indicators, or know about `Surface`; applications keep the
/// offset in their own state and use this helper to clamp it and derive the
/// visible range.
pub const Viewport = struct {
    /// Total number of items or lines in the backing collection.
    total: usize = 0,
    /// Number of items or lines that can be visible at once.
    height: usize = 0,
    /// Requested scroll offset into the backing collection.
    offset: usize = 0,

    /// Initial values used when constructing a viewport.
    pub const Options = struct {
        total: usize = 0,
        height: usize = 0,
        offset: usize = 0,
    };

    /// Half-open visible range into the backing collection.
    pub const Range = struct {
        start: usize,
        end: usize,
    };

    /// Create a viewport.
    pub fn init(opts: Options) Viewport {
        return .{
            .total = opts.total,
            .height = opts.height,
            .offset = opts.offset,
        };
    }

    /// Return the largest valid offset for this viewport.
    pub fn maxOffset(self: Viewport) usize {
        return maxOffsetFor(self.total, self.height);
    }

    /// Return `offset` clamped to the valid range.
    pub fn clampedOffset(self: Viewport) usize {
        return @min(self.offset, self.maxOffset());
    }

    /// Return a copy with `offset` clamped to the valid range.
    pub fn withClampedOffset(self: Viewport) Viewport {
        return .{
            .total = self.total,
            .height = self.height,
            .offset = self.clampedOffset(),
        };
    }

    /// Return the half-open visible range for the clamped offset.
    pub fn visibleRange(self: Viewport) Range {
        if (self.total == 0 or self.height == 0) return .{ .start = 0, .end = 0 };

        const start = self.clampedOffset();
        return .{
            .start = start,
            .end = @min(self.total, start +| self.height),
        };
    }

    /// Return an offset that keeps absolute `index` inside the visible range.
    ///
    /// `index` is an index into the full backing collection, not a local row
    /// inside the currently visible range. Values past the end are treated as
    /// the last item. Empty collections and zero-height viewports return `0`.
    pub fn offsetKeepingIndexVisible(total: usize, height: usize, offset: usize, index: usize) usize {
        if (total == 0 or height == 0) return 0;

        const max_offset = maxOffsetFor(total, height);
        const clamped_offset = @min(offset, max_offset);
        const clamped_index = @min(index, total - 1);

        if (clamped_index < clamped_offset) return clamped_index;

        const visible_end = clamped_offset +| height;
        if (clamped_index >= visible_end) {
            const next_offset = if (clamped_index >= height) clamped_index - height + 1 else 0;
            return @min(next_offset, max_offset);
        }

        return clamped_offset;
    }
};

fn maxOffsetFor(total: usize, height: usize) usize {
    if (height == 0 or total <= height) return 0;
    return total - height;
}

test "Viewport initializes from options" {
    const viewport = Viewport.init(.{ .total = 10, .height = 4, .offset = 2 });

    try std.testing.expectEqual(@as(usize, 10), viewport.total);
    try std.testing.expectEqual(@as(usize, 4), viewport.height);
    try std.testing.expectEqual(@as(usize, 2), viewport.offset);
}

test "Viewport returns empty range for empty or zero-height input" {
    try std.testing.expectEqual(Viewport.Range{ .start = 0, .end = 0 }, Viewport.init(.{ .total = 0, .height = 5, .offset = 0 }).visibleRange());
    try std.testing.expectEqual(Viewport.Range{ .start = 0, .end = 0 }, Viewport.init(.{ .total = 5, .height = 0, .offset = 0 }).visibleRange());
}

test "Viewport shows full range when content fits" {
    const viewport = Viewport.init(.{ .total = 3, .height = 5, .offset = 10 });

    try std.testing.expectEqual(@as(usize, 0), viewport.maxOffset());
    try std.testing.expectEqual(@as(usize, 0), viewport.clampedOffset());
    try std.testing.expectEqual(Viewport.Range{ .start = 0, .end = 3 }, viewport.visibleRange());
}

test "Viewport clamps offset and calculates visible range" {
    const viewport = Viewport.init(.{ .total = 10, .height = 4, .offset = 8 });

    try std.testing.expectEqual(@as(usize, 6), viewport.maxOffset());
    try std.testing.expectEqual(@as(usize, 6), viewport.clampedOffset());
    try std.testing.expectEqual(Viewport.Range{ .start = 6, .end = 10 }, viewport.visibleRange());
}

test "Viewport withClampedOffset preserves dimensions" {
    const viewport = Viewport.init(.{ .total = 10, .height = 4, .offset = 99 }).withClampedOffset();

    try std.testing.expectEqual(@as(usize, 10), viewport.total);
    try std.testing.expectEqual(@as(usize, 4), viewport.height);
    try std.testing.expectEqual(@as(usize, 6), viewport.offset);
}

test "Viewport keeps absolute index visible" {
    try std.testing.expectEqual(@as(usize, 0), Viewport.offsetKeepingIndexVisible(10, 4, 0, 3));
    try std.testing.expectEqual(@as(usize, 1), Viewport.offsetKeepingIndexVisible(10, 4, 0, 4));
    try std.testing.expectEqual(@as(usize, 2), Viewport.offsetKeepingIndexVisible(10, 4, 5, 2));
    try std.testing.expectEqual(@as(usize, 5), Viewport.offsetKeepingIndexVisible(10, 4, 5, 8));
}

test "Viewport keep-visible clamps boundary cases" {
    try std.testing.expectEqual(@as(usize, 0), Viewport.offsetKeepingIndexVisible(0, 4, 2, 1));
    try std.testing.expectEqual(@as(usize, 0), Viewport.offsetKeepingIndexVisible(10, 0, 2, 1));
    try std.testing.expectEqual(@as(usize, 6), Viewport.offsetKeepingIndexVisible(10, 4, 99, 99));
}
