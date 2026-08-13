//! Projection between borrowed UTF-8 byte offsets and terminal display cells.
//!
//! Construction validates the complete line and its cell accumulation before
//! exposing a value. Operations and iterators on an admitted projection are
//! therefore infallible and cannot publish a partial geometry result.

const std = @import("std");
const chasen = @import("chasen");

pub const Error = error{
    InvalidUtf8,
    InvalidTabWidth,
    CellOverflow,
};

pub const Options = struct {
    tab_width: usize,
};

pub const ByteRange = struct {
    start: usize,
    end: usize,
};

pub const CellRange = struct {
    start: usize,
    end: usize,

    pub fn width(self: CellRange) usize {
        return self.end - self.start;
    }
};

pub const Token = struct {
    byte_start: usize,
    byte_end: usize,
    cell_start: usize,
    cell_end: usize,

    pub fn bytes(self: Token, line: []const u8) []const u8 {
        return line[self.byte_start..self.byte_end];
    }

    pub fn byteRange(self: Token) ByteRange {
        return .{ .start = self.byte_start, .end = self.byte_end };
    }

    pub fn cellRange(self: Token) CellRange {
        return .{ .start = self.cell_start, .end = self.cell_end };
    }

    pub fn cellWidth(self: Token) usize {
        return self.cell_end - self.cell_start;
    }
};

pub const Boundary = struct {
    byte_offset: usize,
    cell: usize,
};

pub const CellHit = union(enum) {
    token: Token,
    boundary: Boundary,
};

pub const Materialization = union(enum) {
    /// Borrowed source bytes for a complete, non-TAB token.
    source: []const u8,
    /// Space cells for a TAB or the visible part of an atomic token.
    spaces: usize,
};

pub const VisibleSegment = struct {
    token: Token,
    global_cells: CellRange,
    viewport_cells: CellRange,
    materialization: Materialization,
};

pub const Projection = struct {
    line: []const u8,
    options: Options,
    total_cells: usize,

    /// Admit a complete borrowed line before any geometry becomes visible.
    ///
    /// The caller must keep `line` alive and unchanged for the lifetime of the
    /// projection and every iterator derived from it.
    pub fn init(line: []const u8, options: Options) Error!Projection {
        if (!std.unicode.utf8ValidateSlice(line)) return error.InvalidUtf8;
        if (options.tab_width == 0) return error.InvalidTabWidth;

        var total_cells: usize = 0;
        var graphemes = chasen.text.graphemeIterator(line);
        while (graphemes.next()) |grapheme| {
            const width = tokenWidth(options, grapheme.bytes(line), total_cells);
            total_cells = std.math.add(usize, total_cells, width) catch return error.CellOverflow;
        }

        return .{
            .line = line,
            .options = options,
            .total_cells = total_cells,
        };
    }

    pub fn displayWidth(self: Projection) usize {
        return self.total_cells;
    }

    pub fn tokens(self: Projection) TokenIterator {
        return .{
            .line = self.line,
            .options = self.options,
            .graphemes = chasen.text.graphemeIterator(self.line),
        };
    }

    /// Strict retained-coordinate validation. Interior grapheme bytes are not
    /// repaired or rounded.
    pub fn isBoundary(self: Projection, byte_offset: usize) bool {
        return self.cellForBoundary(byte_offset) != null;
    }

    pub fn cellForBoundary(self: Projection, byte_offset: usize) ?usize {
        if (byte_offset > self.line.len) return null;
        if (byte_offset == 0) return 0;

        var iterator = self.tokens();
        while (iterator.next()) |token| {
            if (byte_offset == token.byte_start) return token.cell_start;
            if (byte_offset == token.byte_end) return token.cell_end;
            if (byte_offset < token.byte_end) return null;
        }
        return if (byte_offset == self.line.len) self.total_cells else null;
    }

    /// Tolerant presentation mapping. Offsets beyond EOL clamp to EOL, while
    /// an interior byte maps to its containing token's leading cell.
    pub fn leadingCellForByte(self: Projection, byte_offset: usize) usize {
        const target = @min(byte_offset, self.line.len);
        var iterator = self.tokens();
        while (iterator.next()) |token| {
            if (target <= token.byte_start) return token.cell_start;
            if (target < token.byte_end) return token.cell_start;
            if (target == token.byte_end) return token.cell_end;
        }
        return self.total_cells;
    }

    /// Tolerantly enclose every grapheme touched by a byte range. An empty or
    /// entirely out-of-line range has no presentation cells.
    pub fn enclosingCellsForBytes(self: Projection, bytes: ByteRange) ?CellRange {
        if (bytes.start >= bytes.end or bytes.start >= self.line.len) return null;
        const clamped_end = @min(bytes.end, self.line.len);
        var first: ?usize = null;
        var last: usize = 0;

        var iterator = self.tokens();
        while (iterator.next()) |token| {
            if (token.byte_end <= bytes.start) continue;
            if (token.byte_start >= clamped_end) break;
            if (first == null) first = token.cell_start;
            last = token.cell_end;
        }

        return if (first) |start| .{ .start = start, .end = last } else null;
    }

    /// Map every occupied cell of an atomic token to that same token. Empty
    /// lines and cells at or beyond EOL resolve to the trailing boundary.
    pub fn hitCell(self: Projection, cell: usize) CellHit {
        var iterator = self.tokens();
        while (iterator.next()) |token| {
            if (token.cell_start <= cell and cell < token.cell_end) {
                return .{ .token = token };
            }
        }
        return .{ .boundary = .{
            .byte_offset = self.line.len,
            .cell = self.total_cells,
        } };
    }

    pub fn tokenAtCell(self: Projection, cell: usize) ?Token {
        return switch (self.hitCell(cell)) {
            .token => |token| token,
            .boundary => null,
        };
    }

    /// Apply horizontal scroll exactly once. Saturation maps an unrepresentable
    /// absolute cell to the trailing boundary rather than wrapping.
    pub fn hitViewportCell(self: Projection, horizontal_scroll: usize, viewport_cell: usize) CellHit {
        return self.hitCell(horizontal_scroll +| viewport_cell);
    }

    /// Iterate the raw cell viewport `[scroll, saturating(scroll + width))`.
    /// Zero-cell tokens have valid byte boundaries but own no cell and are
    /// intentionally not yielded.
    pub fn visibleSegments(self: Projection, horizontal_scroll: usize, width: usize) VisibleIterator {
        return .{
            .line = self.line,
            .tokens = self.tokens(),
            .viewport_start = horizontal_scroll,
            .viewport_end = horizontal_scroll +| width,
        };
    }
};

pub const TokenIterator = struct {
    line: []const u8,
    options: Options,
    graphemes: chasen.text.GraphemeIterator,
    cell: usize = 0,

    pub fn next(self: *TokenIterator) ?Token {
        const grapheme = self.graphemes.next() orelse return null;
        const width = tokenWidth(self.options, grapheme.bytes(self.line), self.cell);
        const cell_end = std.math.add(usize, self.cell, width) catch unreachable;
        const token: Token = .{
            .byte_start = grapheme.start,
            .byte_end = grapheme.start + grapheme.len,
            .cell_start = self.cell,
            .cell_end = cell_end,
        };
        self.cell = cell_end;
        return token;
    }
};

pub const VisibleIterator = struct {
    line: []const u8,
    tokens: TokenIterator,
    viewport_start: usize,
    viewport_end: usize,

    pub fn next(self: *VisibleIterator) ?VisibleSegment {
        if (self.viewport_start >= self.viewport_end) return null;

        while (self.tokens.next()) |token| {
            if (token.cell_end <= self.viewport_start) continue;
            if (token.cell_start >= self.viewport_end) return null;

            const start = @max(token.cell_start, self.viewport_start);
            const end = @min(token.cell_end, self.viewport_end);
            if (start >= end) continue;

            const global_cells: CellRange = .{ .start = start, .end = end };
            const viewport_cells: CellRange = .{
                .start = start - self.viewport_start,
                .end = end - self.viewport_start,
            };
            const bytes = token.bytes(self.line);
            const complete = start == token.cell_start and end == token.cell_end;
            const materialization: Materialization = if (isTab(bytes) or !complete)
                .{ .spaces = global_cells.width() }
            else
                .{ .source = bytes };

            return .{
                .token = token,
                .global_cells = global_cells,
                .viewport_cells = viewport_cells,
                .materialization = materialization,
            };
        }
        return null;
    }
};

fn tokenWidth(options: Options, bytes: []const u8, cell: usize) usize {
    if (isTab(bytes)) return options.tab_width - (cell % options.tab_width);
    return chasen.text.displayWidth(bytes);
}

fn isTab(bytes: []const u8) bool {
    return bytes.len == 1 and bytes[0] == '\t';
}

test "projection admits the whole line before exposing traversal" {
    const invalid = [_]u8{0xff};
    try std.testing.expectError(error.InvalidUtf8, Projection.init(&invalid, .{ .tab_width = 4 }));
    try std.testing.expectError(error.InvalidTabWidth, Projection.init("text", .{ .tab_width = 0 }));
    try std.testing.expectError(error.CellOverflow, Projection.init("\tA", .{ .tab_width = std.math.maxInt(usize) }));

    const maximal = try Projection.init("\t", .{ .tab_width = std.math.maxInt(usize) });
    try std.testing.expectEqual(std.math.maxInt(usize), maximal.displayWidth());
}

test "tokens project caller-specified TAB wide combining and emoji cells" {
    const line = "a\t界e\u{301}👩‍🚀";
    const projection = try Projection.init(line, .{ .tab_width = 4 });
    var iterator = projection.tokens();

    try expectToken(&iterator, line, "a", .{ .start = 0, .end = 1 });
    try expectToken(&iterator, line, "\t", .{ .start = 1, .end = 4 });
    try expectToken(&iterator, line, "界", .{ .start = 4, .end = 6 });
    try expectToken(&iterator, line, "e\u{301}", .{ .start = 6, .end = 7 });
    try expectToken(&iterator, line, "👩‍🚀", .{ .start = 7, .end = 9 });
    try std.testing.expect(iterator.next() == null);
    try std.testing.expectEqual(@as(usize, 9), projection.displayWidth());

    try std.testing.expectEqual(@as(usize, 4), (try Projection.init("\t", .{ .tab_width = 4 })).displayWidth());
    try std.testing.expectEqual(@as(usize, 4), (try Projection.init("a\t", .{ .tab_width = 4 })).displayWidth());
    try std.testing.expectEqual(@as(usize, 4), (try Projection.init("ab\t", .{ .tab_width = 4 })).displayWidth());
    try std.testing.expectEqual(@as(usize, 8), (try Projection.init("a\t", .{ .tab_width = 8 })).displayWidth());
}

test "non-zero tokens round-trip strict boundaries and every occupied cell" {
    const line = "A\t界e\u{301}👩‍🚀";
    const projection = try Projection.init(line, .{ .tab_width = 4 });
    var iterator = projection.tokens();

    while (iterator.next()) |token| {
        try std.testing.expectEqual(@as(?usize, token.cell_start), projection.cellForBoundary(token.byte_start));
        try std.testing.expectEqual(@as(?usize, token.cell_end), projection.cellForBoundary(token.byte_end));
        for (token.cell_start..token.cell_end) |cell| {
            try std.testing.expectEqual(token, projection.hitCell(cell).token);
            const scroll = @min(cell, 2);
            try std.testing.expectEqual(token, projection.hitViewportCell(scroll, cell - scroll).token);
        }
    }

    const trailing = projection.hitCell(projection.displayWidth()).boundary;
    try std.testing.expectEqual(line.len, trailing.byte_offset);
    try std.testing.expectEqual(projection.displayWidth(), trailing.cell);
}

test "strict boundaries reject interiors while tolerant ranges enclose graphemes" {
    const combining = "e\u{301}";
    const line = combining ++ "界x";
    const projection = try Projection.init(line, .{ .tab_width = 4 });

    try std.testing.expect(projection.isBoundary(0));
    try std.testing.expect(!projection.isBoundary(1));
    try std.testing.expectEqual(@as(?usize, null), projection.cellForBoundary(1));
    try std.testing.expectEqual(@as(?usize, 1), projection.cellForBoundary(combining.len));
    try std.testing.expectEqual(@as(?usize, 3), projection.cellForBoundary(combining.len + "界".len));
    try std.testing.expectEqual(@as(usize, 0), projection.leadingCellForByte(1));
    try std.testing.expectEqual(projection.displayWidth(), projection.leadingCellForByte(line.len + 10));
    try std.testing.expectEqual(
        CellRange{ .start = 0, .end = 1 },
        projection.enclosingCellsForBytes(.{ .start = 1, .end = 2 }).?,
    );
}

test "occupied TAB and wide cells hit one atomic token" {
    const projection = try Projection.init("a\t界", .{ .tab_width = 4 });
    const tab = projection.tokenAtCell(1).?;
    try std.testing.expectEqual(tab, projection.tokenAtCell(2).?);
    try std.testing.expectEqual(tab, projection.tokenAtCell(3).?);
    const wide = projection.tokenAtCell(4).?;
    try std.testing.expectEqual(wide, projection.tokenAtCell(5).?);
    try std.testing.expectEqual(tab, projection.hitViewportCell(2, 0).token);

    const trailing = projection.hitCell(6).boundary;
    try std.testing.expectEqual(@as(usize, "a\t界".len), trailing.byte_offset);
    try std.testing.expectEqual(@as(usize, 6), trailing.cell);
    try std.testing.expect(projection.hitViewportCell(std.math.maxInt(usize), 1) == .boundary);
}

test "zero-width graphemes preserve boundaries without owning hit cells" {
    const zero = "\u{301}";
    const line = zero ++ "x";
    const projection = try Projection.init(line, .{ .tab_width = 4 });
    var tokens = projection.tokens();
    const first = tokens.next().?;

    try std.testing.expectEqual(@as(usize, 0), first.cellWidth());
    try std.testing.expectEqual(@as(?usize, 0), projection.cellForBoundary(0));
    try std.testing.expectEqual(@as(?usize, 0), projection.cellForBoundary(zero.len));
    try std.testing.expectEqual(@as(usize, zero.len), projection.tokenAtCell(0).?.byte_start);

    var visible = projection.visibleSegments(0, 1);
    const segment = visible.next().?;
    try std.testing.expectEqualStrings("x", segment.materialization.source);
    try std.testing.expect(visible.next() == null);
}

test "visible segments materialize TAB and partial atomic tokens as spaces" {
    const line = "a\t界B";
    const projection = try Projection.init(line, .{ .tab_width = 4 });
    var visible = projection.visibleSegments(2, 4);

    const tab = visible.next().?;
    try std.testing.expectEqual(CellRange{ .start = 2, .end = 4 }, tab.global_cells);
    try std.testing.expectEqual(CellRange{ .start = 0, .end = 2 }, tab.viewport_cells);
    try std.testing.expectEqual(@as(usize, 2), tab.materialization.spaces);

    const wide = visible.next().?;
    try std.testing.expectEqual(CellRange{ .start = 4, .end = 6 }, wide.global_cells);
    try std.testing.expectEqual(CellRange{ .start = 2, .end = 4 }, wide.viewport_cells);
    try std.testing.expectEqualStrings("界", wide.materialization.source);
    try std.testing.expect(visible.next() == null);

    var partial = projection.visibleSegments(3, 2);
    try std.testing.expectEqual(@as(usize, 1), partial.next().?.materialization.spaces);
    try std.testing.expectEqual(@as(usize, 1), partial.next().?.materialization.spaces);
    try std.testing.expect(partial.next() == null);

    const atomic = try Projection.init("界👩‍🚀", .{ .tab_width = 4 });
    var partial_atomic = atomic.visibleSegments(1, 2);
    try std.testing.expectEqual(@as(usize, 1), partial_atomic.next().?.materialization.spaces);
    try std.testing.expectEqual(@as(usize, 1), partial_atomic.next().?.materialization.spaces);
    try std.testing.expect(partial_atomic.next() == null);
}

test "empty and zero-width viewports have deterministic terminals" {
    const empty = try Projection.init("", .{ .tab_width = 4 });
    try std.testing.expectEqual(@as(usize, 0), empty.displayWidth());
    try std.testing.expectEqual(@as(usize, 0), empty.hitCell(20).boundary.byte_offset);

    const projection = try Projection.init("text", .{ .tab_width = 4 });
    var visible = projection.visibleSegments(2, 0);
    try std.testing.expect(visible.next() == null);
    try std.testing.expect(projection.enclosingCellsForBytes(.{ .start = 2, .end = 2 }) == null);
}

fn expectToken(iterator: *TokenIterator, line: []const u8, expected: []const u8, cells: CellRange) !void {
    const token = iterator.next() orelse return error.MissingToken;
    try std.testing.expectEqualStrings(expected, token.bytes(line));
    try std.testing.expectEqual(cells, token.cellRange());
}
