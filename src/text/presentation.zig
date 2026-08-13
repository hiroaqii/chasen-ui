//! Projection-backed terminal text presentation.
//!
//! Pure geometry values borrow fully admitted projections and allocate
//! nothing. Materialization is explicit: `Clip.materialize` transfers one
//! allocation and its final projection to the caller, while `drawAt` stores
//! that backing in the Surface frame arena before issuing one borrowed draw.

const std = @import("std");
const chasen = @import("chasen");
const projection = @import("projection.zig");

pub const Direction = enum {
    /// Preserve the leading source and place the marker after it.
    head,
    /// Preserve the trailing source and place the marker before it.
    tail,
};

pub const Segment = projection.Materialization;

pub const TerminalError = error{
    UnstableTerminalSerialization,
};

pub const MaterializeError = std.mem.Allocator.Error || projection.Error || TerminalError;

/// A strict borrowed subrange of one admitted projection.
///
/// The projection's original bytes must remain alive and unchanged while the
/// range or any iterator derived from it is used. `text` may contain TABs; use
/// `segments` or `Clip.materialize` for terminal-ready bytes.
pub const Range = struct {
    projection: projection.Projection,
    bytes: projection.ByteRange,
    cells: projection.CellRange,

    pub fn full(admitted: projection.Projection) Range {
        return .{
            .projection = admitted,
            .bytes = .{ .start = 0, .end = admitted.line.len },
            .cells = .{ .start = 0, .end = admitted.displayWidth() },
        };
    }

    /// Create a range only when both offsets are strict grapheme boundaries.
    pub fn fromBytes(admitted: projection.Projection, bytes: projection.ByteRange) ?Range {
        if (bytes.start > bytes.end or bytes.end > admitted.line.len) return null;
        const cell_start = admitted.cellForBoundary(bytes.start) orelse return null;
        const cell_end = admitted.cellForBoundary(bytes.end) orelse return null;
        return .{
            .projection = admitted,
            .bytes = bytes,
            .cells = .{ .start = cell_start, .end = cell_end },
        };
    }

    /// Return the borrowed source bytes. TABs are not expanded in this view.
    pub fn text(self: Range) []const u8 {
        return self.projection.line[self.bytes.start..self.bytes.end];
    }

    pub fn displayWidth(self: Range) usize {
        return self.cells.width();
    }

    /// Traverse terminal-ready borrowed source segments and TAB space counts.
    pub fn segments(self: Range) RangeIterator {
        return .{ .visible = self.projection.visibleSegments(self.cells.start, self.cells.width()) };
    }
};

pub const RangeIterator = struct {
    visible: projection.VisibleIterator,

    pub fn next(self: *RangeIterator) ?Segment {
        const segment = self.visible.next() orelse return null;
        return segment.materialization;
    }
};

/// Preserve only complete tokens that fit within `available_cells`.
pub fn clip(source: Range, available_cells: usize, direction: Direction) Range {
    if (source.displayWidth() <= available_cells) return source;

    return switch (direction) {
        .head => clipHead(source, available_cells),
        .tail => dropLeading(source, source.displayWidth() - available_cells),
    };
}

fn clipHead(source: Range, available_cells: usize) Range {
    var byte_end = source.bytes.start;
    var cell_end = source.cells.start;
    const cell_limit = source.cells.start +| available_cells;
    var tokens = source.projection.tokens();

    while (tokens.next()) |token| {
        if (token.byte_end <= source.bytes.start) continue;
        if (token.byte_start >= source.bytes.end) break;
        if (token.cell_end > cell_limit) break;
        byte_end = token.byte_end;
        cell_end = token.cell_end;
    }

    return .{
        .projection = source.projection,
        .bytes = .{ .start = source.bytes.start, .end = byte_end },
        .cells = .{ .start = source.cells.start, .end = cell_end },
    };
}

/// Drop complete leading tokens until at least `cells` display cells have
/// been skipped. A request inside an atomic token snaps forward.
pub fn dropLeading(source: Range, cells: usize) Range {
    if (cells == 0) return source;

    var byte_start = source.bytes.end;
    var cell_start = source.cells.end;
    var tokens = source.projection.tokens();

    while (tokens.next()) |token| {
        if (token.byte_end <= source.bytes.start) continue;
        if (token.byte_start >= source.bytes.end) break;
        byte_start = token.byte_end;
        cell_start = token.cell_end;
        if (token.cell_end - source.cells.start >= cells) break;
    }

    return .{
        .projection = source.projection,
        .bytes = .{ .start = byte_start, .end = source.bytes.end },
        .cells = .{ .start = cell_start, .end = source.cells.end },
    };
}

/// A composable source/marker presentation plan.
///
/// `source` is public so application-owned policy may replace it with another
/// strict subrange of the same admitted source before traversal. Such a
/// replacement must not exceed the original source cell budget.
pub const Clip = struct {
    source: Range,
    marker: ?Range,
    direction: Direction,
    clipped: bool,

    pub fn displayWidth(self: Clip) usize {
        return self.source.displayWidth() + if (self.marker) |marker| marker.displayWidth() else 0;
    }

    /// Traverse source then marker for `.head`, marker then source for `.tail`.
    pub fn segments(self: Clip) ClipIterator {
        return .{
            .source = self.source.segments(),
            .marker = if (self.marker) |marker| marker.segments() else null,
            .direction = self.direction,
        };
    }

    /// Build one final terminal serialization owned by `allocator`.
    ///
    /// The complete current source and marker ranges are validated before
    /// sizing. Success transfers exactly one backing allocation; the caller
    /// must call `Materialized.deinit` exactly once.
    pub fn materialize(self: Clip, allocator: std.mem.Allocator) MaterializeError!Materialized {
        try ensureClipSingleLine(self);

        const source_byte_len = try rangeByteLen(self.source);
        const marker_byte_len = if (self.marker) |marker| try rangeByteLen(marker) else 0;
        const byte_len = std.math.add(usize, source_byte_len, marker_byte_len) catch
            return error.UnstableTerminalSerialization;

        const backing = try allocator.alloc(u8, byte_len);
        errdefer allocator.free(backing);

        var offset: usize = 0;
        var seam: ?usize = null;
        switch (self.direction) {
            .head => {
                fillRange(self.source, backing, &offset);
                if (source_byte_len != 0 and marker_byte_len != 0) seam = offset;
                if (self.marker) |marker| fillRange(marker, backing, &offset);
            },
            .tail => {
                if (self.marker) |marker| fillRange(marker, backing, &offset);
                if (source_byte_len != 0 and marker_byte_len != 0) seam = offset;
                fillRange(self.source, backing, &offset);
            },
        }
        std.debug.assert(offset == backing.len);

        const final_projection = try projection.Projection.init(backing, .{ .tab_width = 1 });
        if (seam) |boundary| {
            if (!final_projection.isBoundary(boundary)) return error.UnstableTerminalSerialization;
        }

        var tokens = final_projection.tokens();
        while (tokens.next()) |token| {
            if (token.cellWidth() == 0) return error.UnstableTerminalSerialization;
        }
        if (final_projection.displayWidth() != self.displayWidth()) {
            return error.UnstableTerminalSerialization;
        }

        return .{
            .backing = backing,
            .projection = final_projection,
        };
    }
};

/// One caller-owned final serialization and its cell-authoritative projection.
///
/// Every borrowed slice or iterator becomes invalid after `deinit`.
pub const Materialized = struct {
    backing: []u8,
    projection: projection.Projection,

    pub fn text(self: Materialized) []const u8 {
        return self.backing;
    }

    pub fn segments(self: Materialized) RangeIterator {
        return Range.full(self.projection).segments();
    }

    pub fn displayWidth(self: Materialized) usize {
        return self.projection.displayWidth();
    }

    pub fn deinit(self: *Materialized, allocator: std.mem.Allocator) void {
        allocator.free(self.backing);
        self.* = undefined;
    }
};

pub const ClipIterator = struct {
    source: RangeIterator,
    marker: ?RangeIterator,
    direction: Direction,
    phase: enum { first, second, done } = .first,

    pub fn next(self: *ClipIterator) ?Segment {
        while (true) {
            switch (self.phase) {
                .first => {
                    const segment = switch (self.direction) {
                        .head => self.source.next(),
                        .tail => if (self.marker) |*marker| marker.next() else null,
                    };
                    if (segment) |value| return value;
                    self.phase = .second;
                },
                .second => {
                    const segment = switch (self.direction) {
                        .head => if (self.marker) |*marker| marker.next() else null,
                        .tail => self.source.next(),
                    };
                    if (segment) |value| return value;
                    self.phase = .done;
                },
                .done => return null,
            }
        }
    }
};

fn segmentByteLen(segment: Segment) usize {
    return switch (segment) {
        .source => |bytes| bytes.len,
        .spaces => |count| count,
    };
}

fn ensureSingleLine(bytes: []const u8) TerminalError!void {
    if (std.mem.indexOfScalar(u8, bytes, '\n') != null) {
        return error.UnstableTerminalSerialization;
    }
}

fn ensureClipSingleLine(value: Clip) TerminalError!void {
    try ensureSingleLine(value.source.text());
    if (value.marker) |marker| try ensureSingleLine(marker.text());
}

fn rangeByteLen(range: Range) TerminalError!usize {
    var byte_len: usize = 0;
    var sizing = range.segments();
    while (sizing.next()) |segment| {
        byte_len = std.math.add(usize, byte_len, segmentByteLen(segment)) catch
            return error.UnstableTerminalSerialization;
    }
    return byte_len;
}

fn fillRange(range: Range, backing: []u8, offset: *usize) void {
    var filling = range.segments();
    while (filling.next()) |segment| {
        switch (segment) {
            .source => |bytes| {
                @memcpy(backing[offset.*..][0..bytes.len], bytes);
                offset.* += bytes.len;
            },
            .spaces => |count| {
                @memset(backing[offset.*..][0..count], ' ');
                offset.* += count;
            },
        }
    }
}

/// Compose a marker with a clipped source without allocation.
///
/// Source that already fits is returned unchanged with no marker. On
/// truncation the marker reserves up to its admitted width and is itself
/// head-clipped. The source receives only the unreserved budget, so a
/// non-empty atomic marker that cannot fit is omitted rather than replaced by
/// source. Empty and zero-cell markers reserve nothing.
pub fn markedClip(source: Range, marker_projection: projection.Projection, available_cells: usize, direction: Direction) TerminalError!Clip {
    try ensureSingleLine(source.text());
    try ensureSingleLine(marker_projection.line);

    if (source.displayWidth() <= available_cells) {
        return .{ .source = source, .marker = null, .direction = direction, .clipped = false };
    }

    const marker_full = Range.full(marker_projection);
    const marker = clip(marker_full, available_cells, .head);
    const marker_reservation = @min(marker_full.displayWidth(), available_cells);
    const source_budget = available_cells - marker_reservation;
    return .{
        .source = clip(source, source_budget, direction),
        .marker = marker,
        .direction = direction,
        .clipped = true,
    };
}

/// A projection-backed horizontal window that keeps the presentation cursor
/// visible without changing the caller's byte offset.
pub const CursorWindow = struct {
    range: Range,
    /// Requested byte offset clamped only to end-of-line.
    cursor_byte: usize,
    /// Tolerant absolute presentation cell; interior bytes use token leading cell.
    anchor_cell: usize,
    /// Cursor cell relative to `range`.
    cursor_cell: usize,

    pub fn init(admitted: projection.Projection, requested_byte: usize, available_cells: usize) CursorWindow {
        const cursor_byte = @min(requested_byte, admitted.line.len);
        const anchor_cell = admitted.leadingCellForByte(cursor_byte);

        if (available_cells == 0) {
            const empty = Range.fromBytes(admitted, .{
                .start = admitted.line.len,
                .end = admitted.line.len,
            }).?;
            return .{
                .range = empty,
                .cursor_byte = cursor_byte,
                .anchor_cell = anchor_cell,
                .cursor_cell = 0,
            };
        }

        const preceding_budget = available_cells - 1;
        const minimum_start = anchor_cell -| preceding_budget;
        const range = dropLeading(Range.full(admitted), minimum_start);
        return .{
            .range = range,
            .cursor_byte = cursor_byte,
            .anchor_cell = anchor_cell,
            .cursor_cell = anchor_cell - range.cells.start,
        };
    }
};

/// Draw one already-composed clip using one Surface-frame allocation and one
/// borrowed Surface write. Out-of-bounds and empty draws allocate and write
/// nothing. Allocation failure leaves the Surface unchanged.
pub fn drawAt(surface: *chasen.Surface, col: u16, row: u16, value: Clip, style: chasen.TextStyle) MaterializeError!void {
    try ensureClipSingleLine(value);

    const size = surface.size();
    if (col >= size.width or row >= size.height or value.displayWidth() == 0) return;

    const materialized = try value.materialize(surface.frameAllocator());
    if (materialized.text().len == 0) return;
    _ = surface.borrowTextAt(col, row, materialized.text(), style);
}

pub const DrawOptions = struct {
    tab_width: usize,
    marker: []const u8,
    direction: Direction,
};

pub const DrawError = MaterializeError;

/// Fully admit raw source and marker bytes, clip to the remaining Surface row,
/// and draw using the same pure `Clip` contract as range-oriented consumers.
pub fn drawClippedAt(
    surface: *chasen.Surface,
    col: u16,
    row: u16,
    text: []const u8,
    style: chasen.TextStyle,
    options: DrawOptions,
) DrawError!void {
    const source_projection = try projection.Projection.init(text, .{ .tab_width = options.tab_width });
    const marker_projection = try projection.Projection.init(options.marker, .{ .tab_width = options.tab_width });

    try ensureSingleLine(source_projection.line);
    try ensureSingleLine(marker_projection.line);

    const size = surface.size();
    if (col >= size.width or row >= size.height) return;
    const available_cells: usize = size.width - col;
    const value = try markedClip(Range.full(source_projection), marker_projection, available_cells, options.direction);
    try drawAt(surface, col, row, value, style);
}

test "strict ranges borrow source and traverse terminal-ready segments" {
    const line = "a\t界e\u{301}👩‍🚀";
    const admitted = try projection.Projection.init(line, .{ .tab_width = 4 });
    const full = Range.full(admitted);

    try std.testing.expectEqualStrings(line, full.text());
    try std.testing.expectEqual(@as(usize, 9), full.displayWidth());

    var segments = full.segments();
    try expectSource(&segments, "a");
    try expectSpaces(&segments, 3);
    try expectSource(&segments, "界");
    try expectSource(&segments, "e\u{301}");
    try expectSource(&segments, "👩‍🚀");
    try std.testing.expect(segments.next() == null);

    const combining_start = "a\t界".len;
    const combining_end = combining_start + "e\u{301}".len;
    const combining = Range.fromBytes(admitted, .{ .start = combining_start, .end = combining_end }).?;
    try std.testing.expectEqualStrings("e\u{301}", combining.text());
    try std.testing.expectEqual(@as(usize, 1), combining.displayWidth());

    try std.testing.expect(Range.fromBytes(admitted, .{ .start = combining_start + 1, .end = combining_end }) == null);
    try std.testing.expect(Range.fromBytes(admitted, .{ .start = 3, .end = 2 }) == null);
    try std.testing.expect(Range.fromBytes(admitted, .{ .start = 0, .end = line.len + 1 }) == null);
}

test "head tail and drop operations keep atomic projection boundaries" {
    const line = "A界e\u{301}👩‍🚀Z";
    const admitted = try projection.Projection.init(line, .{ .tab_width = 4 });
    const full = Range.full(admitted);

    try std.testing.expectEqualStrings("A界", clip(full, 3, .head).text());
    try std.testing.expectEqualStrings("👩‍🚀Z", clip(full, 3, .tail).text());
    try std.testing.expectEqualStrings("e\u{301}👩‍🚀Z", dropLeading(full, 2).text());
    try std.testing.expectEqualStrings("e\u{301}👩‍🚀Z", dropLeading(full, 3).text());
    try std.testing.expectEqualStrings("", dropLeading(full, std.math.maxInt(usize)).text());

    const leading_zero = try projection.Projection.init("\u{301}A", .{ .tab_width = 4 });
    try std.testing.expectEqualStrings("\u{301}", clip(Range.full(leading_zero), 0, .head).text());
    var zero_segments = clip(Range.full(leading_zero), 0, .head).segments();
    try std.testing.expect(zero_segments.next() == null);
}

test "TAB materialization retains original global columns after slicing" {
    const tab4 = try projection.Projection.init("abc\tX", .{ .tab_width = 4 });
    const tail4 = dropLeading(Range.full(tab4), 3);
    const value4: Clip = .{ .source = tail4, .marker = null, .direction = .head, .clipped = false };
    var rendered4 = try value4.materialize(std.testing.allocator);
    defer rendered4.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(" X", rendered4.text());

    const tab8 = try projection.Projection.init("a\tZ", .{ .tab_width = 8 });
    const tail8 = dropLeading(Range.full(tab8), 1);
    const value8: Clip = .{ .source = tail8, .marker = null, .direction = .head, .clipped = false };
    var rendered8 = try value8.materialize(std.testing.allocator);
    defer rendered8.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("       Z", rendered8.text());
}

test "marked clipping distinguishes exact fit and head tail truncation" {
    const source = try projection.Projection.init("abcd", .{ .tab_width = 4 });
    const marker = try projection.Projection.init("…", .{ .tab_width = 4 });

    const exact = try markedClip(Range.full(source), marker, 4, .head);
    try std.testing.expect(!exact.clipped);
    try std.testing.expect(exact.marker == null);
    try expectMaterialized(exact, "abcd");

    const head = try markedClip(Range.full(source), marker, 3, .head);
    try std.testing.expect(head.clipped);
    try expectMaterialized(head, "ab…");
    var head_segments = head.segments();
    try expectClipSource(&head_segments, "a");
    try expectClipSource(&head_segments, "b");
    try expectClipSource(&head_segments, "…");
    try std.testing.expect(head_segments.next() == null);

    const tail = try markedClip(Range.full(source), marker, 3, .tail);
    try std.testing.expect(tail.clipped);
    try expectMaterialized(tail, "…cd");
    var tail_segments = tail.segments();
    try expectClipSource(&tail_segments, "…");
    try expectClipSource(&tail_segments, "c");
    try expectClipSource(&tail_segments, "d");
    try std.testing.expect(tail_segments.next() == null);
}

test "marker priority has deterministic zero and one cell terminals" {
    const source = try projection.Projection.init("abcd", .{ .tab_width = 4 });
    const ellipsis = try projection.Projection.init("…", .{ .tab_width = 4 });
    const path_marker = try projection.Projection.init("…/", .{ .tab_width = 4 });

    const zero = try markedClip(Range.full(source), ellipsis, 0, .head);
    try std.testing.expect(zero.clipped);
    try std.testing.expectEqual(@as(usize, 0), zero.displayWidth());
    try expectMaterialized(zero, "");
    try expectMaterialized(try markedClip(Range.full(source), ellipsis, 1, .head), "…");
    try expectMaterialized(try markedClip(Range.full(source), path_marker, 0, .tail), "");
    try expectMaterialized(try markedClip(Range.full(source), path_marker, 1, .tail), "…");
    try expectMaterialized(try markedClip(Range.full(source), path_marker, 2, .tail), "…/");
    try expectMaterialized(try markedClip(Range.full(source), path_marker, 3, .tail), "…/d");

    const empty_source = try projection.Projection.init("\u{301}", .{ .tab_width = 4 });
    const fits_zero_cells = try markedClip(Range.full(empty_source), ellipsis, 0, .head);
    try std.testing.expect(!fits_zero_cells.clipped);
    try std.testing.expect(fits_zero_cells.marker == null);
    try expectMaterialized(fits_zero_cells, "");
}

test "empty zero-cell markers reserve nothing and a non-fitting atomic marker leaves no fallback" {
    const source = try projection.Projection.init("abcd", .{ .tab_width = 4 });
    const empty = try projection.Projection.init("", .{ .tab_width = 4 });
    const zero_cell = try projection.Projection.init("\u{301}", .{ .tab_width = 4 });
    const wide = try projection.Projection.init("界", .{ .tab_width = 4 });

    try expectMaterialized(try markedClip(Range.full(source), empty, 2, .head), "ab");
    try expectMaterialized(try markedClip(Range.full(source), zero_cell, 2, .head), "ab");
    try expectMaterialized(try markedClip(Range.full(source), wide, 1, .head), "");
}

test "wide combining emoji and TAB source tokens are never split" {
    const marker = try projection.Projection.init("…", .{ .tab_width = 4 });

    const wide = try projection.Projection.init("界A", .{ .tab_width = 4 });
    try expectMaterialized(try markedClip(Range.full(wide), marker, 2, .head), "…");
    try expectMaterialized(try markedClip(Range.full(wide), marker, 2, .tail), "…A");

    const combining = try projection.Projection.init("e\u{301}X", .{ .tab_width = 4 });
    try expectMaterialized(try markedClip(Range.full(combining), marker, 2, .head), "e\u{301}X");
    try expectMaterialized(try markedClip(Range.full(combining), marker, 1, .head), "…");

    const emoji = try projection.Projection.init("👩‍🚀X", .{ .tab_width = 4 });
    try expectMaterialized(try markedClip(Range.full(emoji), marker, 2, .head), "…");
    try expectMaterialized(try markedClip(Range.full(emoji), marker, 2, .tail), "…X");

    const tab = try projection.Projection.init("a\tX", .{ .tab_width = 4 });
    try expectMaterialized(try markedClip(Range.full(tab), marker, 3, .head), "a…");
    try expectMaterialized(try markedClip(Range.full(tab), marker, 3, .tail), "…X");
}

test "application policy can replace the canonical strict source subrange" {
    const source = try projection.Projection.init("very/deep/file.zig", .{ .tab_width = 4 });
    const marker = try projection.Projection.init("…/", .{ .tab_width = 4 });
    var value = try markedClip(Range.full(source), marker, 11, .tail);
    try std.testing.expect(value.clipped);
    try std.testing.expect(std.mem.startsWith(u8, value.source.text(), "/"));
    value.source = Range.fromBytes(source, .{
        .start = value.source.bytes.start + 1,
        .end = value.source.bytes.end,
    }).?;
    try expectMaterialized(value, "…/file.zig");
}

test "cursor window keeps start middle EOL and beyond-EOL anchors visible" {
    const admitted = try projection.Projection.init("abcdef", .{ .tab_width = 4 });

    const start = CursorWindow.init(admitted, 0, 4);
    try std.testing.expectEqualStrings("abcdef", start.range.text());
    try std.testing.expectEqual(@as(usize, 0), start.cursor_cell);

    const middle = CursorWindow.init(admitted, 5, 4);
    try std.testing.expectEqualStrings("cdef", middle.range.text());
    try std.testing.expectEqual(@as(usize, 5), middle.cursor_byte);
    try std.testing.expectEqual(@as(usize, 5), middle.anchor_cell);
    try std.testing.expectEqual(@as(usize, 3), middle.cursor_cell);

    const eol = CursorWindow.init(admitted, admitted.line.len, 4);
    const beyond = CursorWindow.init(admitted, admitted.line.len + 100, 4);
    try std.testing.expectEqualStrings("def", eol.range.text());
    try std.testing.expectEqual(@as(usize, 3), eol.cursor_cell);
    try std.testing.expectEqual(admitted.line.len, beyond.cursor_byte);
    try std.testing.expectEqual(eol.anchor_cell, beyond.anchor_cell);
    try std.testing.expectEqual(eol.cursor_cell, beyond.cursor_cell);

    const one = CursorWindow.init(admitted, 3, 1);
    try std.testing.expectEqualStrings("def", one.range.text());
    try std.testing.expectEqual(@as(usize, 0), one.cursor_cell);

    const zero = CursorWindow.init(admitted, 3, 0);
    try std.testing.expectEqualStrings("", zero.range.text());
    try std.testing.expectEqual(@as(usize, 0), zero.cursor_cell);

    const maximal = CursorWindow.init(admitted, 5, std.math.maxInt(usize));
    try std.testing.expectEqualStrings("abcdef", maximal.range.text());
    try std.testing.expectEqual(@as(usize, 5), maximal.cursor_cell);
}

test "cursor window preserves global TAB stops and tolerant atomic anchors" {
    const tab = try projection.Projection.init("a\tB", .{ .tab_width = 4 });
    const after_tab = CursorWindow.init(tab, 2, 3);
    try std.testing.expectEqualStrings("B", after_tab.range.text());
    try std.testing.expectEqual(@as(usize, 4), after_tab.anchor_cell);
    try std.testing.expectEqual(@as(usize, 0), after_tab.cursor_cell);

    const combining = "e\u{301}";
    const line = "A" ++ combining ++ "界👩‍🚀Z";
    const admitted = try projection.Projection.init(line, .{ .tab_width = 4 });
    const combining_interior = CursorWindow.init(admitted, 2, 4);
    try std.testing.expectEqual(@as(usize, 2), combining_interior.cursor_byte);
    try std.testing.expectEqual(@as(usize, 1), combining_interior.anchor_cell);
    try std.testing.expect(combining_interior.cursor_cell < 4);

    const wide_start = 1 + combining.len;
    const wide_interior = CursorWindow.init(admitted, wide_start + 1, 2);
    try std.testing.expectEqual(@as(usize, 2), wide_interior.anchor_cell);
    try std.testing.expect(wide_interior.cursor_cell < 2);

    const emoji_start = wide_start + "界".len;
    const emoji_interior = CursorWindow.init(admitted, emoji_start + 1, 3);
    try std.testing.expectEqual(@as(usize, 4), emoji_interior.anchor_cell);
    try std.testing.expect(emoji_interior.cursor_cell < 3);

    const marker = try projection.Projection.init("…", .{ .tab_width = 4 });
    const presented = try markedClip(emoji_interior.range, marker, 3, .head);
    try std.testing.expectEqual(@as(usize, 3), presented.displayWidth());
    try expectMaterialized(presented, "界…");
}

test "materialization owns one allocation and reports allocation failure" {
    const source = try projection.Projection.init("a\t界", .{ .tab_width = 4 });
    const marker = try projection.Projection.init("…", .{ .tab_width = 4 });
    const value = try markedClip(Range.full(source), marker, 5, .head);

    var one_allocation = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    var rendered = try value.materialize(one_allocation.allocator());
    try std.testing.expectEqual(@as(usize, 1), one_allocation.allocations);
    try std.testing.expect(!one_allocation.has_induced_failure);
    try std.testing.expectEqualStrings("a   …", rendered.text());
    try std.testing.expectEqual(value.displayWidth(), rendered.displayWidth());
    var final_segments = rendered.segments();
    try expectSource(&final_segments, "a");
    try expectSource(&final_segments, " ");
    try expectSource(&final_segments, " ");
    try expectSource(&final_segments, " ");
    try expectSource(&final_segments, "…");
    try std.testing.expect(final_segments.next() == null);
    rendered.deinit(one_allocation.allocator());
    try std.testing.expectEqual(one_allocation.allocated_bytes, one_allocation.freed_bytes);

    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, value.materialize(failing.allocator()));
    try std.testing.expect(failing.has_induced_failure);
    try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
}

test "final serialization rejects an unsafe source marker seam" {
    const source = try projection.Projection.init("🇺XYZ", .{ .tab_width = 4 });
    const marker = try projection.Projection.init("🇸", .{ .tab_width = 4 });
    const value = try markedClip(Range.full(source), marker, 4, .head);

    try std.testing.expectEqual(@as(usize, 4), value.displayWidth());
    try std.testing.expectError(
        error.UnstableTerminalSerialization,
        value.materialize(std.testing.allocator),
    );
}

test "final serialization rejects fusion after non-LF zero-cell omission" {
    const source = try projection.Projection.init("🇺\u{200b}🇸", .{ .tab_width = 4 });
    const value: Clip = .{
        .source = Range.full(source),
        .marker = null,
        .direction = .head,
        .clipped = false,
    };

    try std.testing.expectError(
        error.UnstableTerminalSerialization,
        value.materialize(std.testing.allocator),
    );
}

test "marked clipping rejects LF before fit width and marker decisions" {
    const marker = try projection.Projection.init("…", .{ .tab_width = 4 });
    const middle_lf = try projection.Projection.init("A\nB", .{ .tab_width = 4 });
    const ending_lf = try projection.Projection.init("A\n", .{ .tab_width = 4 });
    const safe = try projection.Projection.init("ok", .{ .tab_width = 4 });
    const marker_leading_lf = try projection.Projection.init("\n…", .{ .tab_width = 4 });
    const marker_trailing_lf = try projection.Projection.init("…\n", .{ .tab_width = 4 });

    try std.testing.expectError(
        error.UnstableTerminalSerialization,
        markedClip(Range.full(middle_lf), marker, 80, .head),
    );
    try std.testing.expectError(
        error.UnstableTerminalSerialization,
        markedClip(Range.full(middle_lf), marker, 0, .tail),
    );
    try std.testing.expectError(
        error.UnstableTerminalSerialization,
        markedClip(Range.full(ending_lf), marker, 80, .head),
    );
    try std.testing.expectError(
        error.UnstableTerminalSerialization,
        markedClip(Range.full(safe), marker_leading_lf, 2, .head),
    );
    try std.testing.expectError(
        error.UnstableTerminalSerialization,
        markedClip(Range.full(safe), marker_trailing_lf, 0, .tail),
    );
}

test "current source or marker replacement with LF fails before allocation or Surface effect" {
    const source = try projection.Projection.init("safeA\nB", .{ .tab_width = 4 });
    const marker = try projection.Projection.init("…", .{ .tab_width = 4 });
    const initial = Range.fromBytes(source, .{ .start = 0, .end = "safe".len }).?;
    var value = try markedClip(initial, marker, 4, .head);
    value.source = Range.fromBytes(source, .{ .start = "safe".len, .end = source.line.len }).?;

    var materialize_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(
        error.UnstableTerminalSerialization,
        value.materialize(materialize_failing.allocator()),
    );
    try std.testing.expectEqual(@as(usize, 0), materialize_failing.allocations);
    try std.testing.expect(!materialize_failing.has_induced_failure);

    const long_source = try projection.Projection.init("replace", .{ .tab_width = 4 });
    var marker_value = try markedClip(Range.full(long_source), marker, 4, .head);
    const replacement_marker = try projection.Projection.init("bad\nmarker", .{ .tab_width = 4 });
    marker_value.marker = Range.fromBytes(replacement_marker, .{
        .start = 0,
        .end = replacement_marker.line.len,
    });
    try std.testing.expectError(
        error.UnstableTerminalSerialization,
        marker_value.materialize(materialize_failing.allocator()),
    );
    try std.testing.expectEqual(@as(usize, 0), materialize_failing.allocations);
    try std.testing.expect(!materialize_failing.has_induced_failure);

    var draw_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var ts: chasen.testing.TestSurface = undefined;
    try ts.initWithAllocator(6, 1, draw_failing.allocator());
    defer ts.deinit();
    _ = ts.surface.borrowTextAt(0, 0, "stable", .{});
    draw_failing.fail_index = draw_failing.alloc_index;

    try std.testing.expectError(
        error.UnstableTerminalSerialization,
        drawAt(&ts.surface, 6, 0, value, .{}),
    );
    try std.testing.expect(!draw_failing.has_induced_failure);
    try ts.expectSnapshot("stable");
}

test "raw drawing rejects source and marker LF before bounds and empty returns" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var ts: chasen.testing.TestSurface = undefined;
    try ts.initWithAllocator(6, 1, failing.allocator());
    defer ts.deinit();
    _ = ts.surface.borrowTextAt(0, 0, "stable", .{});

    failing.fail_index = failing.alloc_index;
    try std.testing.expectError(error.UnstableTerminalSerialization, drawClippedAt(
        &ts.surface,
        6,
        0,
        "A\nB",
        .{},
        .{ .tab_width = 4, .marker = "…", .direction = .head },
    ));
    try std.testing.expectError(error.UnstableTerminalSerialization, drawClippedAt(
        &ts.surface,
        0,
        0,
        "ok",
        .{},
        .{ .tab_width = 4, .marker = "unused\nmarker", .direction = .head },
    ));
    try std.testing.expect(!failing.has_induced_failure);
    try ts.expectSnapshot("stable");
}

test "drawClippedAt uses frame-owned bytes and preserves style" {
    var ts: chasen.testing.TestSurface = undefined;
    try ts.init(5, 1);
    defer ts.deinit();

    var source = [_]u8{ 'a', 'b', 'c', 'd', 'e', 'f' };
    try drawClippedAt(&ts.surface, 0, 0, &source, .{ .bold = true }, .{
        .tab_width = 4,
        .marker = "…",
        .direction = .head,
    });
    source[0] = 'z';

    try ts.expectCellText(0, 0, "a");
    try ts.expectCellText(3, 0, "d");
    try ts.expectCellText(4, 0, "…");
    try std.testing.expect(ts.surface.readCell(0, 0).?.style.bold);
}

test "drawClippedAt expands TABs and leaves out-of-bounds draws inert" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var ts: chasen.testing.TestSurface = undefined;
    try ts.initWithAllocator(5, 1, failing.allocator());
    defer ts.deinit();

    const allocations_before_draw = failing.allocations;
    try drawClippedAt(&ts.surface, 0, 0, "a\tB", .{}, .{
        .tab_width = 4,
        .marker = "…",
        .direction = .head,
    });
    try std.testing.expectEqual(allocations_before_draw + 1, failing.allocations);
    try ts.expectSnapshot("a   B");

    failing.fail_index = failing.alloc_index;
    try drawClippedAt(&ts.surface, 5, 0, "outside", .{}, .{
        .tab_width = 4,
        .marker = "…",
        .direction = .head,
    });
    try drawClippedAt(&ts.surface, 0, 1, "outside", .{}, .{
        .tab_width = 4,
        .marker = "…",
        .direction = .head,
    });
    try std.testing.expect(!failing.has_induced_failure);
    try ts.expectSnapshot("a   B");
}

test "draw allocation and admission failures have no Surface effect" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var ts: chasen.testing.TestSurface = undefined;
    try ts.initWithAllocator(6, 1, failing.allocator());
    defer ts.deinit();
    _ = ts.surface.borrowTextAt(0, 0, "stable", .{});

    const source = try projection.Projection.init("replace", .{ .tab_width = 4 });
    const marker = try projection.Projection.init("…", .{ .tab_width = 4 });
    const value = try markedClip(Range.full(source), marker, 6, .head);
    failing.fail_index = failing.alloc_index;
    try std.testing.expectError(error.OutOfMemory, drawAt(&ts.surface, 0, 0, value, .{}));
    try ts.expectSnapshot("stable");

    failing.fail_index = std.math.maxInt(usize);
    const invalid = [_]u8{0xff};
    try std.testing.expectError(error.InvalidUtf8, drawClippedAt(&ts.surface, 0, 0, &invalid, .{}, .{
        .tab_width = 4,
        .marker = "…",
        .direction = .head,
    }));
    try std.testing.expectError(error.InvalidUtf8, drawClippedAt(&ts.surface, 0, 0, "valid", .{}, .{
        .tab_width = 4,
        .marker = &invalid,
        .direction = .head,
    }));
    try std.testing.expectError(error.InvalidTabWidth, drawClippedAt(&ts.surface, 0, 0, "valid", .{}, .{
        .tab_width = 0,
        .marker = "…",
        .direction = .head,
    }));
    try std.testing.expectError(error.CellOverflow, drawClippedAt(&ts.surface, 0, 0, "\tA", .{}, .{
        .tab_width = std.math.maxInt(usize),
        .marker = "…",
        .direction = .head,
    }));
    try std.testing.expectError(error.CellOverflow, drawClippedAt(&ts.surface, 0, 0, "valid", .{}, .{
        .tab_width = std.math.maxInt(usize),
        .marker = "\tA",
        .direction = .head,
    }));
    try ts.expectSnapshot("stable");
}

fn expectSource(iterator: *RangeIterator, expected: []const u8) !void {
    const segment = iterator.next() orelse return error.MissingSegment;
    switch (segment) {
        .source => |bytes| try std.testing.expectEqualStrings(expected, bytes),
        .spaces => return error.ExpectedSource,
    }
}

fn expectSpaces(iterator: *RangeIterator, expected: usize) !void {
    const segment = iterator.next() orelse return error.MissingSegment;
    switch (segment) {
        .source => return error.ExpectedSpaces,
        .spaces => |count| try std.testing.expectEqual(expected, count),
    }
}

fn expectClipSource(iterator: *ClipIterator, expected: []const u8) !void {
    const segment = iterator.next() orelse return error.MissingSegment;
    switch (segment) {
        .source => |bytes| try std.testing.expectEqualStrings(expected, bytes),
        .spaces => return error.ExpectedSource,
    }
}

fn expectMaterialized(value: Clip, expected: []const u8) !void {
    var actual = try value.materialize(std.testing.allocator);
    defer actual.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(expected, actual.text());
}
