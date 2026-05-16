const std = @import("std");
const chasen = @import("chasen");

/// A small display-only table component.
///
/// `Table` borrows column definitions and row cell text. It draws fixed-width
/// columns into a clipped region, but it does not own sorting, selection,
/// scrolling, column resizing, or data loading. Applications prepare the rows
/// they want to show and decide what each cell means.
pub const Table = struct {
    /// Horizontal alignment for a column.
    pub const Align = enum {
        left,
        center,
        right,
    };

    /// Table grid style.
    pub const Grid = enum {
        /// Draw cells only, without header separator or borders.
        none,
        /// Draw the current lightweight style: cells plus optional header separator.
        minimal,
        /// Draw spreadsheet-like outer borders, column separators, and row separators.
        full,
    };

    /// Glyphs used when `ViewOptions.grid` is `.full`.
    ///
    /// Glyphs are expected to occupy one terminal cell.
    pub const GridStyle = struct {
        top_left: []const u8 = "+",
        top: []const u8 = "-",
        top_join: []const u8 = "+",
        top_right: []const u8 = "+",
        left: []const u8 = "|",
        join: []const u8 = "+",
        right: []const u8 = "|",
        bottom_left: []const u8 = "+",
        bottom: []const u8 = "-",
        bottom_join: []const u8 = "+",
        bottom_right: []const u8 = "+",
        vertical: []const u8 = "|",
        horizontal: []const u8 = "-",

        pub const ascii: GridStyle = .{};
        pub const rounded: GridStyle = .{
            .top_left = "╭",
            .top = "─",
            .top_join = "┬",
            .top_right = "╮",
            .left = "│",
            .join = "┼",
            .right = "│",
            .bottom_left = "╰",
            .bottom = "─",
            .bottom_join = "┴",
            .bottom_right = "╯",
            .vertical = "│",
            .horizontal = "─",
        };
    };

    /// One table column.
    pub const Column = struct {
        /// Header label borrowed by the component.
        header: []const u8,
        /// Fixed column width in terminal cells.
        width: u16,
        /// Alignment used for header and cell text.
        alignment: Align = .left,
    };

    /// One borrowed row. Missing cells are rendered as empty strings.
    pub const Row = []const []const u8;

    /// Initial values used when constructing a `Table`.
    pub const Options = struct {
        /// Column definitions borrowed by the component for its lifetime.
        columns: []const Column = &.{},
        /// Row cells borrowed by the component for its lifetime.
        rows: []const Row = &.{},
    };

    /// Rendering options for `Table.view`.
    pub const ViewOptions = struct {
        /// Spaces between columns.
        column_gap: u16 = 2,
        /// Grid chrome drawn around and between table cells.
        grid: Grid = .minimal,
        /// Glyphs used for `.full` grid chrome.
        grid_style: GridStyle = .ascii,
        /// Whether to draw the header row.
        show_header: bool = true,
        /// Whether to draw a separator row after the header.
        show_separator: bool = true,
        /// Style used for header text.
        header_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for separator glyphs.
        separator_style: chasen.TextStyle = .{ .dim = true },
        /// Style used for body cell text.
        cell_style: chasen.TextStyle = .{},
    };

    /// Column definitions borrowed by the component.
    columns: []const Column = &.{},
    /// Row cells borrowed by the component.
    rows: []const Row = &.{},

    /// Create a table.
    pub fn init(opts: Options) Table {
        return .{
            .columns = opts.columns,
            .rows = opts.rows,
        };
    }

    /// Return the table's natural display width before parent clipping.
    pub fn naturalWidth(self: *const Table, column_gap: u16) u16 {
        return columnsWidth(self.columns, column_gap);
    }

    /// Return the table's natural display width for a grid mode.
    pub fn naturalWidthFor(self: *const Table, column_gap: u16, grid: Grid) u16 {
        return switch (grid) {
            .none, .minimal => columnsWidth(self.columns, column_gap),
            .full => fullGridWidth(self.columns),
        };
    }

    /// Return how many rows can be drawn before parent clipping.
    pub fn visibleRowCapacity(self: *const Table, height: u16, show_header: bool, show_separator: bool) usize {
        _ = self;
        if (height == 0) return 0;
        const header_rows = headerHeight(show_header, show_separator);
        if (height <= header_rows) return 0;
        return height - header_rows;
    }

    /// Return how many body rows can be fully drawn for a grid mode.
    pub fn visibleRowCapacityFor(self: *const Table, height: u16, show_header: bool, show_separator: bool, grid: Grid) usize {
        return switch (grid) {
            .none, .minimal => self.visibleRowCapacity(height, show_header, show_separator),
            .full => fullGridVisibleRowCapacity(height, show_header, show_separator),
        };
    }

    /// Draw the table into the provided clipped surface region.
    pub fn view(self: *const Table, surface: *chasen.Surface, opts: ViewOptions) void {
        const size = surface.size();
        const width = size.width;
        const height = size.height;
        if (width == 0 or height == 0 or self.columns.len == 0) return;

        if (opts.grid == .full) {
            drawFullGrid(surface, self.columns, self.rows, opts, width, height);
            return;
        }

        var row: u16 = 0;
        if (opts.show_header) {
            drawHeader(surface, row, self.columns, opts.column_gap, opts.header_style, width);
            row += 1;
        }

        if (opts.grid == .minimal and opts.show_header and opts.show_separator and row < height) {
            drawSeparator(surface, row, self.columns, opts.column_gap, opts.separator_style, width);
            row += 1;
        }

        for (self.rows) |cells| {
            if (row >= height) break;
            drawRow(surface, row, self.columns, cells, opts.column_gap, opts.cell_style, width);
            row += 1;
        }
    }
};

fn columnsWidth(columns: []const Table.Column, column_gap: u16) u16 {
    var width: u16 = 0;
    for (columns, 0..) |column, i| {
        if (i > 0) width +|= column_gap;
        width +|= column.width;
    }
    return width;
}

fn fullGridWidth(columns: []const Table.Column) u16 {
    var width: u16 = 1;
    for (columns) |column| {
        width +|= column.width;
        width +|= 1;
    }
    return width;
}

fn headerHeight(show_header: bool, show_separator: bool) u16 {
    if (!show_header) return 0;
    return if (show_separator) 2 else 1;
}

fn fullGridVisibleRowCapacity(height: u16, show_header: bool, show_separator: bool) usize {
    if (height <= 1) return 0;
    const header_rows: u16 = if (!show_header) 0 else if (show_separator) 2 else 1;
    if (height <= 1 + header_rows) return 0;
    const body_space = height - 1 - header_rows;
    return if (show_separator) body_space / 2 else body_space;
}

fn drawFullGrid(
    surface: *chasen.Surface,
    columns: []const Table.Column,
    rows: []const Table.Row,
    opts: Table.ViewOptions,
    max_width: u16,
    max_height: u16,
) void {
    if (max_width == 0 or max_height == 0) return;

    var row: u16 = 0;
    drawGridLine(surface, row, columns, opts.grid_style, .top, opts.separator_style, max_width);
    row += 1;
    if (row >= max_height) return;

    if (opts.show_header) {
        drawGridContentRow(surface, row, columns, null, opts.grid_style, opts.separator_style, opts.header_style, max_width);
        row += 1;
        if (row >= max_height) return;
        if (opts.show_separator) {
            drawGridLine(surface, row, columns, opts.grid_style, .middle, opts.separator_style, max_width);
            row += 1;
            if (row >= max_height) return;
        }
    }

    for (rows, 0..) |cells, i| {
        drawGridContentRow(surface, row, columns, cells, opts.grid_style, opts.separator_style, opts.cell_style, max_width);
        row += 1;
        if (row >= max_height) return;
        if (opts.show_separator or i + 1 == rows.len) {
            const line_kind: GridLineKind = if (i + 1 == rows.len) .bottom else .middle;
            drawGridLine(surface, row, columns, opts.grid_style, line_kind, opts.separator_style, max_width);
            row += 1;
            if (row >= max_height) return;
        }
    }

    if (rows.len == 0) {
        drawGridLine(surface, row, columns, opts.grid_style, .bottom, opts.separator_style, max_width);
    }
}

const GridLineKind = enum {
    top,
    middle,
    bottom,
};

fn drawGridLine(
    surface: *chasen.Surface,
    row: u16,
    columns: []const Table.Column,
    style: Table.GridStyle,
    kind: GridLineKind,
    text_style: chasen.TextStyle,
    max_width: u16,
) void {
    var cursor: u16 = 0;
    drawGridGlyph(surface, &cursor, row, gridLeftGlyph(style, kind), text_style, max_width);
    for (columns, 0..) |column, i| {
        drawRepeatedGlyph(surface, &cursor, row, style.horizontal, column.width, text_style, max_width);
        const is_last = i + 1 == columns.len;
        drawGridGlyph(surface, &cursor, row, if (is_last) gridRightGlyph(style, kind) else gridJoinGlyph(style, kind), text_style, max_width);
    }
}

fn drawGridContentRow(
    surface: *chasen.Surface,
    row: u16,
    columns: []const Table.Column,
    maybe_cells: ?Table.Row,
    grid_style: Table.GridStyle,
    grid_text_style: chasen.TextStyle,
    text_style: chasen.TextStyle,
    max_width: u16,
) void {
    var cursor: u16 = 0;
    drawGridGlyph(surface, &cursor, row, grid_style.vertical, grid_text_style, max_width);
    for (columns, 0..) |column, i| {
        if (cursor >= max_width) return;

        const remaining = max_width - cursor;
        const width = @min(column.width, remaining);
        if (width > 0) {
            const text = if (maybe_cells) |cells| cellText(cells, i) else column.header;
            drawCell(surface, cursor, row, width, text, column.alignment, text_style);
        }
        cursor +|= column.width;
        drawGridGlyph(surface, &cursor, row, grid_style.vertical, grid_text_style, max_width);
    }
}

fn gridLeftGlyph(style: Table.GridStyle, kind: GridLineKind) []const u8 {
    return switch (kind) {
        .top => style.top_left,
        .middle => style.left,
        .bottom => style.bottom_left,
    };
}

fn gridJoinGlyph(style: Table.GridStyle, kind: GridLineKind) []const u8 {
    return switch (kind) {
        .top => style.top_join,
        .middle => style.join,
        .bottom => style.bottom_join,
    };
}

fn gridRightGlyph(style: Table.GridStyle, kind: GridLineKind) []const u8 {
    return switch (kind) {
        .top => style.top_right,
        .middle => style.right,
        .bottom => style.bottom_right,
    };
}

fn drawGridGlyph(surface: *chasen.Surface, cursor: *u16, row: u16, glyph: []const u8, style: chasen.TextStyle, max_width: u16) void {
    if (cursor.* >= max_width) return;
    _ = surface.textAt(cursor.*, row, glyph, style);
    cursor.* +|= 1;
}

fn drawRepeatedGlyph(surface: *chasen.Surface, cursor: *u16, row: u16, glyph: []const u8, count: u16, style: chasen.TextStyle, max_width: u16) void {
    var index: u16 = 0;
    while (index < count and cursor.* < max_width) : (index += 1) {
        _ = surface.textAt(cursor.*, row, glyph, style);
        cursor.* +|= 1;
    }
}

fn drawHeader(
    surface: *chasen.Surface,
    row: u16,
    columns: []const Table.Column,
    column_gap: u16,
    style: chasen.TextStyle,
    max_width: u16,
) void {
    var cursor: u16 = 0;
    for (columns, 0..) |column, i| {
        if (i > 0) cursor +|= column_gap;
        if (cursor >= max_width) return;

        const remaining = max_width - cursor;
        const width = @min(column.width, remaining);
        if (width > 0) {
            drawCell(surface, cursor, row, width, column.header, column.alignment, style);
        }
        cursor +|= column.width;
    }
}

fn drawRow(
    surface: *chasen.Surface,
    row: u16,
    columns: []const Table.Column,
    cells: Table.Row,
    column_gap: u16,
    style: chasen.TextStyle,
    max_width: u16,
) void {
    var cursor: u16 = 0;
    for (columns, 0..) |column, i| {
        if (i > 0) cursor +|= column_gap;
        if (cursor >= max_width) return;

        const remaining = max_width - cursor;
        const width = @min(column.width, remaining);
        if (width > 0) {
            drawCell(surface, cursor, row, width, cellText(cells, i), column.alignment, style);
        }
        cursor +|= column.width;
    }
}

fn drawSeparator(
    surface: *chasen.Surface,
    row: u16,
    columns: []const Table.Column,
    column_gap: u16,
    style: chasen.TextStyle,
    max_width: u16,
) void {
    var cursor: u16 = 0;
    for (columns, 0..) |column, i| {
        if (i > 0) cursor +|= column_gap;
        if (cursor >= max_width) return;

        const remaining = max_width - cursor;
        const width = @min(column.width, remaining);
        var col: u16 = 0;
        while (col < width) : (col += 1) {
            _ = surface.textAt(cursor + col, row, "-", style);
        }
        cursor +|= column.width;
    }
}

fn drawCell(
    surface: *chasen.Surface,
    col: u16,
    row: u16,
    width: u16,
    text: []const u8,
    alignment: Table.Align,
    style: chasen.TextStyle,
) void {
    var child = surface.child(.{
        .col = col,
        .row = row,
        .width = width,
        .height = 1,
    });
    _ = child.textAt(alignedCol(text, width, alignment), 0, text, style);
}

fn cellText(cells: Table.Row, index: usize) []const u8 {
    if (index >= cells.len) return "";
    return cells[index];
}

fn alignedCol(text: []const u8, width: u16, alignment: Table.Align) u16 {
    const text_width = chasen.text.displayWidth(text);
    if (text_width >= width) return 0;
    return switch (alignment) {
        .left => 0,
        .center => (width - text_width) / 2,
        .right => width - text_width,
    };
}

test "Table initializes from options" {
    const columns = [_]Table.Column{
        .{ .header = "Name", .width = 12 },
        .{ .header = "Score", .width = 5, .alignment = .right },
    };
    const rows = [_]Table.Row{
        &.{ "Catan", "7.1" },
    };
    const table = Table.init(.{ .columns = &columns, .rows = &rows });

    try std.testing.expectEqual(@as(usize, 2), table.columns.len);
    try std.testing.expectEqual(@as(usize, 1), table.rows.len);
}

test "Table naturalWidth includes gaps" {
    const columns = [_]Table.Column{
        .{ .header = "A", .width = 3 },
        .{ .header = "B", .width = 4 },
        .{ .header = "C", .width = 5 },
    };
    const table = Table.init(.{ .columns = &columns });

    try std.testing.expectEqual(@as(u16, 16), table.naturalWidth(2));
}

test "Table naturalWidthFor supports full grid chrome" {
    const columns = [_]Table.Column{
        .{ .header = "A", .width = 3 },
        .{ .header = "B", .width = 4 },
    };
    const table = Table.init(.{ .columns = &columns });

    try std.testing.expectEqual(@as(u16, 10), table.naturalWidthFor(2, .full));
    try std.testing.expectEqual(@as(u16, 9), table.naturalWidthFor(2, .minimal));
    try std.testing.expectEqual(@as(u16, 7), table.naturalWidthFor(0, .none));
}

test "Table visibleRowCapacity reserves header rows" {
    const table = Table.init(.{});

    try std.testing.expectEqual(@as(usize, 3), table.visibleRowCapacity(5, true, true));
    try std.testing.expectEqual(@as(usize, 4), table.visibleRowCapacity(5, true, false));
    try std.testing.expectEqual(@as(usize, 5), table.visibleRowCapacity(5, false, true));
    try std.testing.expectEqual(@as(usize, 0), table.visibleRowCapacity(1, true, true));
}

test "Table visibleRowCapacityFor accounts for full grid lines" {
    const table = Table.init(.{});

    try std.testing.expectEqual(@as(usize, 2), table.visibleRowCapacityFor(7, true, true, .full));
    try std.testing.expectEqual(@as(usize, 5), table.visibleRowCapacityFor(7, true, false, .full));
    try std.testing.expectEqual(@as(usize, 3), table.visibleRowCapacityFor(7, false, true, .full));
    try std.testing.expectEqual(@as(usize, 6), table.visibleRowCapacityFor(7, false, false, .full));
    try std.testing.expectEqual(@as(usize, 5), table.visibleRowCapacityFor(7, true, true, .minimal));
}

test "Table alignedCol respects display width" {
    try std.testing.expectEqual(@as(u16, 0), alignedCol("abcd", 4, .right));
    try std.testing.expectEqual(@as(u16, 3), alignedCol("abc", 6, .right));
    try std.testing.expectEqual(@as(u16, 1), alignedCol("abcd", 6, .center));
    try std.testing.expectEqual(@as(u16, 2), alignedCol("あ", 4, .right));
}
