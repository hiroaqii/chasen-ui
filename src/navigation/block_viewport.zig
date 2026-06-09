const std = @import("std");

/// Allocation-free viewport planner for variable-height vertical blocks.
///
/// `BlockViewport` does not know what a block means and does not render. Apps
/// keep scroll state and block data, then use this helper to map a global scroll
/// offset into block-local `skip_rows` / `max_rows` slices.
pub const BlockViewport = struct {
    /// One app-owned block with a precomputed terminal-row height.
    pub const Block = struct {
        height: usize = 0,
    };

    /// Summary for a block slice visible in the current viewport.
    pub const VisibleBlock = struct {
        /// Index into the original block list.
        index: usize,
        /// Number of rows to skip inside this block.
        skip_rows: usize,
        /// Maximum rows from this block that fit in the viewport.
        max_rows: usize,
        /// Row inside the target surface where this block slice starts.
        row: u16,
    };

    /// Aggregate range metadata for the requested viewport.
    pub const Range = struct {
        /// Sum of all block heights.
        total_height: usize,
        /// Requested offset clamped to the valid range for `height`.
        clamped_offset: usize,
    };

    /// App-owned scroll state for a block viewport.
    ///
    /// Apps still decide which keys map to scroll commands and which height is
    /// available for content, but this helper keeps the offset clamped whenever
    /// content or viewport height changes.
    pub const State = struct {
        offset: usize = 0,

        /// Clamp the current offset to the valid range for `blocks`.
        pub fn clamp(self: *State, blocks: []const Block, height: usize) void {
            self.offset = BlockViewport.clampOffset(blocks, self.offset, height);
        }

        /// Move by a signed row delta and clamp to the valid range.
        pub fn scrollBy(self: *State, blocks: []const Block, height: usize, delta: isize) void {
            self.offset = offsetBy(self.offset, delta);
            self.clamp(blocks, height);
        }

        /// Move by signed pages, where one page is the current viewport height.
        pub fn pageBy(self: *State, blocks: []const Block, height: usize, pages: isize) void {
            const rows = signedMagnitude(pages) *| height;
            const delta: isize = if (pages < 0) -saturatingIsize(rows) else saturatingIsize(rows);
            self.scrollBy(blocks, height, delta);
        }

        /// Return range metadata for the current offset.
        pub fn range(self: State, blocks: []const Block, height: usize) Range {
            return BlockViewport.range(blocks, self.offset, height);
        }

        /// Return an iterator for the current offset.
        pub fn iterator(self: State, blocks: []const Block, height: usize) Iterator {
            return BlockViewport.iterator(blocks, self.offset, height);
        }
    };

    /// Iterator over visible block slices.
    pub const Iterator = struct {
        blocks: []const Block,
        next_index: usize = 0,
        skip_rows: usize = 0,
        remaining_rows: usize = 0,
        row: usize = 0,

        /// Return the next visible block slice, or `null` when the viewport is exhausted.
        pub fn next(self: *Iterator) ?VisibleBlock {
            if (self.remaining_rows == 0) return null;

            while (self.next_index < self.blocks.len) {
                const index = self.next_index;
                const block_height = self.blocks[index].height;
                const skip = @min(self.skip_rows, block_height);
                const available = block_height - skip;

                self.next_index += 1;
                self.skip_rows = 0;

                if (available == 0) continue;

                const max_rows = @min(available, self.remaining_rows);
                const visible: VisibleBlock = .{
                    .index = index,
                    .skip_rows = skip,
                    .max_rows = max_rows,
                    .row = clampU16(self.row),
                };
                self.remaining_rows -= max_rows;
                self.row +|= max_rows;
                return visible;
            }

            return null;
        }
    };

    /// Return total height and clamped offset for `blocks`.
    pub fn range(blocks: []const Block, offset: usize, height: usize) Range {
        const total = totalHeight(blocks);
        return .{
            .total_height = total,
            .clamped_offset = clampOffsetFor(total, offset, height),
        };
    }

    /// Return an allocation-free iterator over visible block slices.
    pub fn iterator(blocks: []const Block, offset: usize, height: usize) Iterator {
        if (height == 0 or blocks.len == 0) return .{ .blocks = blocks };

        var remaining_offset = clampOffset(blocks, offset, height);
        var next_index: usize = 0;
        while (next_index < blocks.len) : (next_index += 1) {
            const block_height = blocks[next_index].height;
            if (remaining_offset < block_height) break;
            remaining_offset -= block_height;
        }

        return .{
            .blocks = blocks,
            .next_index = next_index,
            .skip_rows = remaining_offset,
            .remaining_rows = height,
        };
    }

    /// Sum block heights with saturating arithmetic.
    pub fn totalHeight(blocks: []const Block) usize {
        var total: usize = 0;
        for (blocks) |block| total +|= block.height;
        return total;
    }

    /// Return the largest valid scroll offset for the block list.
    pub fn maxOffset(blocks: []const Block, height: usize) usize {
        return maxOffsetFor(totalHeight(blocks), height);
    }

    /// Clamp a requested scroll offset to the valid range for the block list.
    pub fn clampOffset(blocks: []const Block, offset: usize, height: usize) usize {
        return clampOffsetFor(totalHeight(blocks), offset, height);
    }
};

fn maxOffsetFor(total_height: usize, height: usize) usize {
    if (height == 0 or total_height <= height) return 0;
    return total_height - height;
}

fn clampOffsetFor(total_height: usize, offset: usize, height: usize) usize {
    return @min(offset, maxOffsetFor(total_height, height));
}

fn clampU16(value: usize) u16 {
    return @intCast(@min(value, std.math.maxInt(u16)));
}

fn offsetBy(offset: usize, delta: isize) usize {
    if (delta < 0) return offset -| signedMagnitude(delta);
    return offset +| signedMagnitude(delta);
}

fn signedMagnitude(value: isize) usize {
    if (value >= 0) return @intCast(value);
    return @as(usize, @intCast(-(value + 1))) + 1;
}

fn saturatingIsize(value: usize) isize {
    return @intCast(@min(value, @as(usize, @intCast(std.math.maxInt(isize)))));
}

test "BlockViewport totals and clamps offsets" {
    const blocks = [_]BlockViewport.Block{
        .{ .height = 1 },
        .{ .height = 4 },
        .{ .height = 10 },
    };

    try std.testing.expectEqual(@as(usize, 15), BlockViewport.totalHeight(&blocks));
    try std.testing.expectEqual(@as(usize, 10), BlockViewport.maxOffset(&blocks, 5));
    try std.testing.expectEqual(@as(usize, 10), BlockViewport.clampOffset(&blocks, 99, 5));
    try std.testing.expectEqual(BlockViewport.Range{ .total_height = 15, .clamped_offset = 10 }, BlockViewport.range(&blocks, 99, 5));
}

test "BlockViewport State clamps scroll movement" {
    const blocks = [_]BlockViewport.Block{
        .{ .height = 2 },
        .{ .height = 5 },
        .{ .height = 2 },
    };
    var state = BlockViewport.State{};

    state.scrollBy(&blocks, 3, 99);
    try std.testing.expectEqual(@as(usize, 6), state.offset);

    state.scrollBy(&blocks, 3, -1);
    try std.testing.expectEqual(@as(usize, 5), state.offset);

    state.scrollBy(&blocks, 3, -99);
    try std.testing.expectEqual(@as(usize, 0), state.offset);
}

test "BlockViewport State pages and exposes range helpers" {
    const blocks = [_]BlockViewport.Block{
        .{ .height = 2 },
        .{ .height = 5 },
        .{ .height = 2 },
    };
    var state = BlockViewport.State{};

    state.pageBy(&blocks, 3, 1);
    try std.testing.expectEqual(@as(usize, 3), state.offset);

    state.pageBy(&blocks, 3, 9);
    try std.testing.expectEqual(@as(usize, 6), state.offset);

    const range_value = state.range(&blocks, 3);
    try std.testing.expectEqual(BlockViewport.Range{ .total_height = 9, .clamped_offset = 6 }, range_value);

    var it = state.iterator(&blocks, 3);
    try std.testing.expectEqual(BlockViewport.VisibleBlock{ .index = 1, .skip_rows = 4, .max_rows = 1, .row = 0 }, it.next().?);
    try std.testing.expectEqual(BlockViewport.VisibleBlock{ .index = 2, .skip_rows = 0, .max_rows = 2, .row = 1 }, it.next().?);
    try std.testing.expectEqual(@as(?BlockViewport.VisibleBlock, null), it.next());
}

test "BlockViewport handles empty and fitting content" {
    const empty = [_]BlockViewport.Block{};
    try std.testing.expectEqual(@as(usize, 0), BlockViewport.totalHeight(&empty));
    try std.testing.expectEqual(@as(usize, 0), BlockViewport.maxOffset(&empty, 3));

    const blocks = [_]BlockViewport.Block{
        .{ .height = 1 },
        .{ .height = 2 },
    };
    try std.testing.expectEqual(@as(usize, 0), BlockViewport.maxOffset(&blocks, 10));
    try std.testing.expectEqual(@as(usize, 0), BlockViewport.clampOffset(&blocks, 99, 10));
}

test "BlockViewport iterator maps full viewport from start" {
    const blocks = [_]BlockViewport.Block{
        .{ .height = 1 },
        .{ .height = 3 },
        .{ .height = 2 },
    };

    var it = BlockViewport.iterator(&blocks, 0, 5);

    try std.testing.expectEqual(BlockViewport.VisibleBlock{ .index = 0, .skip_rows = 0, .max_rows = 1, .row = 0 }, it.next().?);
    try std.testing.expectEqual(BlockViewport.VisibleBlock{ .index = 1, .skip_rows = 0, .max_rows = 3, .row = 1 }, it.next().?);
    try std.testing.expectEqual(BlockViewport.VisibleBlock{ .index = 2, .skip_rows = 0, .max_rows = 1, .row = 4 }, it.next().?);
    try std.testing.expectEqual(@as(?BlockViewport.VisibleBlock, null), it.next());
}

test "BlockViewport iterator starts inside a block" {
    const blocks = [_]BlockViewport.Block{
        .{ .height = 2 },
        .{ .height = 5 },
        .{ .height = 2 },
    };

    var it = BlockViewport.iterator(&blocks, 4, 3);

    try std.testing.expectEqual(BlockViewport.VisibleBlock{ .index = 1, .skip_rows = 2, .max_rows = 3, .row = 0 }, it.next().?);
    try std.testing.expectEqual(@as(?BlockViewport.VisibleBlock, null), it.next());
}

test "BlockViewport iterator clamps oversized offset" {
    const blocks = [_]BlockViewport.Block{
        .{ .height = 2 },
        .{ .height = 5 },
        .{ .height = 2 },
    };

    var it = BlockViewport.iterator(&blocks, 99, 3);

    try std.testing.expectEqual(BlockViewport.VisibleBlock{ .index = 1, .skip_rows = 4, .max_rows = 1, .row = 0 }, it.next().?);
    try std.testing.expectEqual(BlockViewport.VisibleBlock{ .index = 2, .skip_rows = 0, .max_rows = 2, .row = 1 }, it.next().?);
    try std.testing.expectEqual(@as(?BlockViewport.VisibleBlock, null), it.next());
}

test "BlockViewport iterator skips zero-height blocks" {
    const blocks = [_]BlockViewport.Block{
        .{ .height = 0 },
        .{ .height = 2 },
        .{ .height = 0 },
        .{ .height = 2 },
    };

    var it = BlockViewport.iterator(&blocks, 1, 3);

    try std.testing.expectEqual(BlockViewport.VisibleBlock{ .index = 1, .skip_rows = 1, .max_rows = 1, .row = 0 }, it.next().?);
    try std.testing.expectEqual(BlockViewport.VisibleBlock{ .index = 3, .skip_rows = 0, .max_rows = 2, .row = 1 }, it.next().?);
    try std.testing.expectEqual(@as(?BlockViewport.VisibleBlock, null), it.next());
}
