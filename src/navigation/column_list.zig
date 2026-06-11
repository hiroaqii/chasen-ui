const std = @import("std");
const chasen = @import("chasen");
const FocusList = @import("focus_list.zig").FocusList;
const List = @import("list.zig").List;
const ListViewport = @import("list_view.zig").ListViewport;
const selectable = @import("selectable.zig");

/// A focused vertical list whose rows are rendered as aligned columns.
///
/// `ColumnList` is a navigation component, not a rich table widget. It owns
/// focus state and borrows columns/rows. Applications still own sorting,
/// filtering, data loading, source-index mapping, and the meaning of row
/// activation.
pub const ColumnList = struct {
    /// Horizontal alignment for a cell within its computed column width.
    pub const Align = enum {
        left,
        center,
        right,
    };

    /// Column width policy.
    pub const Width = union(enum) {
        /// Fixed terminal-cell width.
        fixed: u16,
        /// Share the remaining row body width after fixed columns and gaps.
        flex,
    };

    /// Optional style fields layered over a row-state base style.
    pub const StylePatch = struct {
        fg: ?chasen.Color = null,
        bg: ?chasen.Color = null,
        bold: ?bool = null,
        dim: ?bool = null,
        reverse: ?bool = null,
    };

    /// One column definition borrowed by the component.
    pub const Column = struct {
        /// Optional header text.
        header: ?[]const u8 = null,
        /// Column width policy.
        width: Width,
        /// Cell alignment for this column.
        alignment: Align = .left,
        /// Style fields applied to body cells in this column.
        style: StylePatch = .{},
        /// Optional full header style override for this column.
        header_style: ?chasen.TextStyle = null,
    };

    /// One borrowed cell.
    pub const Cell = struct {
        text: []const u8,
        style: StylePatch = .{},
    };

    /// One borrowed row. Missing cells are rendered as empty cells.
    pub const Row = []const Cell;

    /// Initial values used when constructing a `ColumnList`.
    pub const Options = struct {
        /// Column definitions borrowed by the component for its lifetime.
        columns: []const Column = &.{},
        /// Row cells borrowed by the component for its lifetime.
        rows: []const Row = &.{},
    };

    /// Messages understood by `ColumnList.update`.
    pub const Msg = List.Msg;

    /// Rendering options for `ColumnList.view`.
    pub const ViewOptions = struct {
        /// Optional callback used to draw focused cell text.
        ///
        /// This keeps `ColumnList` independent from app-specific animation
        /// systems while still allowing focused rows to use richer text
        /// rendering when an app already has it.
        pub const FocusedTextDrawer = *const fn (
            surface: *chasen.Surface,
            col: u16,
            row: u16,
            text: []const u8,
            style: chasen.TextStyle,
            context: ?*const anyopaque,
        ) void;

        /// Optional app-owned selected index to render differently.
        selected_index: ?usize = null,
        /// Style used for unfocused, unselected row cells.
        row_style: chasen.TextStyle = .{},
        /// Style used as the base for focused row cells.
        focused_style: chasen.TextStyle = .{ .bold = true },
        /// Style used as the base for selected row cells when not focused.
        selected_style: chasen.TextStyle = .{},
        /// Style used as the base for selected row cells when focused.
        focused_selected_style: chasen.TextStyle = .{ .bold = true },
        /// Style used for the focus marker.
        marker_style: chasen.TextStyle = .{ .dim = true },
        /// Marker shown before the focused row.
        focused_marker: []const u8 = ">",
        /// Marker shown before other rows.
        marker: []const u8 = " ",
        /// Space between the marker and first column.
        marker_gap: u16 = 1,
        /// Space between adjacent columns.
        column_gap: u16 = 2,
        /// Whether to render column headers above body rows.
        show_header: bool = false,
        /// Default header style.
        header_style: chasen.TextStyle = .{ .bold = true },
        /// Marker appended when cell text is clipped.
        truncate_marker: []const u8 = "…",
        /// Optional focused text drawing hook.
        focused_text_drawer: ?FocusedTextDrawer = null,
        /// App-owned context passed through to `focused_text_drawer`.
        focused_text_drawer_context: ?*const anyopaque = null,
        /// Whether `view` should place the terminal cursor on the focused row.
        show_cursor: bool = true,
    };

    /// Column definitions borrowed by the component.
    columns: []const Column = &.{},
    /// Row cells borrowed by the component.
    rows: []const Row = &.{},
    /// Local focus state for rows.
    focus: FocusList = .{},

    /// Create a column list.
    ///
    /// If `rows` changes, applications should create a new `ColumnList` and
    /// restore/clamp focus themselves when needed.
    pub fn init(opts: Options) ColumnList {
        return .{
            .columns = opts.columns,
            .rows = opts.rows,
            .focus = FocusList.init(opts.rows.len),
        };
    }

    /// Return the currently focused row index.
    pub fn focusedIndex(self: *const ColumnList) usize {
        return self.focus.focused();
    }

    /// Return whether the list has no rows.
    pub fn empty(self: *const ColumnList) bool {
        return self.rows.len == 0;
    }

    /// Apply a component message.
    pub fn update(self: *ColumnList, msg: Msg) void {
        switch (msg) {
            .move_prev => self.focus.movePrev(),
            .move_next => self.focus.moveNext(),
            .activate => {},
        }
    }

    /// Convert a Chasen event into a `ColumnList` message when applicable.
    pub fn handleEvent(self: *const ColumnList, event: chasen.Event) ?Msg {
        return switch (event) {
            .key_press => |key| keyToMsg(self, key),
            else => null,
        };
    }

    /// Draw the column list into the provided surface.
    pub fn view(self: *const ColumnList, surface: *chasen.Surface, opts: ViewOptions) void {
        const size = surface.size();
        if (size.width == 0 or size.height == 0 or self.columns.len == 0) return;

        const marker_width = markerWidth(opts);
        const body_col = marker_width +| opts.marker_gap;
        if (body_col >= size.width) return;

        const header_height: u16 = if (opts.show_header) 1 else 0;
        if (opts.show_header) {
            drawHeader(self.columns, surface, body_col, computeWidths(self.columns, size.width - body_col, opts.column_gap), opts);
        }

        const body_height = size.height -| header_height;
        if (body_height == 0 or self.rows.len == 0) return;

        const range = ListViewport.visibleRange(self.rows.len, self.focusedIndex(), body_height);
        if (range.end <= range.start) return;

        const widths = computeWidths(self.columns, size.width - body_col, opts.column_gap);
        const focused_index = self.focusedIndex();
        for (self.rows[range.start..range.end], 0..) |row_cells, local_index| {
            const global_index = range.start + local_index;
            const row: u16 = header_height + @as(u16, @intCast(local_index));
            if (row >= size.height) break;

            const focused = global_index == focused_index;
            const selected = opts.selected_index != null and opts.selected_index.? == global_index;
            const marker = if (focused) opts.focused_marker else opts.marker;
            _ = surface.borrowTextAt(0, row, marker, opts.marker_style);

            const base_style = rowStyle(opts, focused, selected);
            drawCells(self.columns, row_cells, surface, body_col, row, widths, base_style, focused, opts);
        }

        if (opts.show_cursor and focused_index >= range.start and focused_index < range.end) {
            const cursor_row: u16 = header_height + @as(u16, @intCast(focused_index - range.start));
            if (cursor_row < size.height) surface.showCursor(@min(body_col, size.width - 1), cursor_row);
        }
    }
};

const max_columns = 32;

fn keyToMsg(list: *const ColumnList, key: chasen.Key) ?ColumnList.Msg {
    if (key.matches(chasen.Key.up, .{})) return .move_prev;
    if (key.matches(chasen.Key.down, .{})) return .move_next;
    if (selectable.isActivationKey(key)) {
        if (list.empty()) return null;
        return .{ .activate = list.focusedIndex() };
    }
    return null;
}

fn markerWidth(opts: ColumnList.ViewOptions) u16 {
    return @max(chasen.text.displayWidth(opts.marker), chasen.text.displayWidth(opts.focused_marker));
}

fn computeWidths(columns: []const ColumnList.Column, body_width: u16, column_gap: u16) [max_columns]u16 {
    var widths = [_]u16{0} ** max_columns;
    const count = @min(columns.len, max_columns);
    if (count == 0 or body_width == 0) return widths;

    const gap_count: u16 = @intCast(count - 1);
    const gap_width = saturatingMul(column_gap, gap_count);

    var fixed_width: u16 = 0;
    var flex_count: u16 = 0;
    for (columns[0..count], 0..) |column, index| {
        switch (column.width) {
            .fixed => |width| {
                widths[index] = width;
                fixed_width +|= width;
            },
            .flex => flex_count += 1,
        }
    }

    const available = body_width -| gap_width -| fixed_width;
    const flex_width = if (flex_count == 0) 0 else available / flex_count;
    const remainder = if (flex_count == 0) 0 else available % flex_count;

    var flex_index: u16 = 0;
    for (columns[0..count], 0..) |column, index| {
        switch (column.width) {
            .fixed => {},
            .flex => {
                const extra: u16 = if (flex_index < remainder) 1 else 0;
                widths[index] = flex_width + extra;
                flex_index += 1;
            },
        }
    }

    return widths;
}

fn drawHeader(
    columns: []const ColumnList.Column,
    surface: *chasen.Surface,
    start_col: u16,
    widths: [max_columns]u16,
    opts: ColumnList.ViewOptions,
) void {
    var col = start_col;
    for (columns[0..@min(columns.len, max_columns)], 0..) |column, index| {
        const width = widths[index];
        if (width > 0 and column.header != null) {
            const style = column.header_style orelse opts.header_style;
            drawTextInCell(surface, col, 0, width, column.header.?, column.alignment, style, false, opts);
        }
        col +|= width +| opts.column_gap;
    }
}

fn drawCells(
    columns: []const ColumnList.Column,
    cells: ColumnList.Row,
    surface: *chasen.Surface,
    start_col: u16,
    row: u16,
    widths: [max_columns]u16,
    base_style: chasen.TextStyle,
    focused: bool,
    opts: ColumnList.ViewOptions,
) void {
    var col = start_col;
    for (columns[0..@min(columns.len, max_columns)], 0..) |column, index| {
        const width = widths[index];
        const maybe_cell = if (index < cells.len) cells[index] else null;
        const text = if (maybe_cell) |cell| cell.text else "";
        var style = applyPatch(base_style, column.style);
        if (maybe_cell) |cell| style = applyPatch(style, cell.style);
        if (width > 0) drawTextInCell(surface, col, row, width, text, column.alignment, style, focused, opts);
        col +|= width +| opts.column_gap;
    }
}

fn drawTextInCell(
    surface: *chasen.Surface,
    col: u16,
    row: u16,
    width: u16,
    text: []const u8,
    alignment: ColumnList.Align,
    style: chasen.TextStyle,
    focused: bool,
    opts: ColumnList.ViewOptions,
) void {
    if (width == 0) return;

    const text_width = chasen.text.displayWidth(text);
    if (text_width <= width) {
        drawText(surface, col + alignedOffset(text_width, width, alignment), row, text, style, focused, opts);
        return;
    }

    const truncate_marker = opts.truncate_marker;
    const marker_width = chasen.text.displayWidth(truncate_marker);
    if (marker_width == 0 or marker_width > width) {
        drawText(surface, col, row, chasen.text.clipToWidth(text, width), style, focused, opts);
        return;
    }

    const clipped = chasen.text.clipToWidth(text, width - marker_width);
    drawText(surface, col, row, clipped, style, focused, opts);
    _ = surface.borrowTextAt(col + chasen.text.displayWidth(clipped), row, truncate_marker, style);
}

fn drawText(
    surface: *chasen.Surface,
    col: u16,
    row: u16,
    text: []const u8,
    style: chasen.TextStyle,
    focused: bool,
    opts: ColumnList.ViewOptions,
) void {
    if (focused) {
        if (opts.focused_text_drawer) |drawer| {
            drawer(surface, col, row, text, style, opts.focused_text_drawer_context);
            return;
        }
    }
    _ = surface.borrowTextAt(col, row, text, style);
}

fn alignedOffset(text_width: u16, width: u16, alignment: ColumnList.Align) u16 {
    if (text_width >= width) return 0;
    const remaining = width - text_width;
    return switch (alignment) {
        .left => 0,
        .center => remaining / 2,
        .right => remaining,
    };
}

fn rowStyle(opts: ColumnList.ViewOptions, focused: bool, selected: bool) chasen.TextStyle {
    if (focused and selected) return opts.focused_selected_style;
    if (focused) return opts.focused_style;
    if (selected) return opts.selected_style;
    return opts.row_style;
}

fn applyPatch(base: chasen.TextStyle, patch: ColumnList.StylePatch) chasen.TextStyle {
    var style = base;
    if (patch.fg) |value| style.fg = value;
    if (patch.bg) |value| style.bg = value;
    if (patch.bold) |value| style.bold = value;
    if (patch.dim) |value| style.dim = value;
    if (patch.reverse) |value| style.reverse = value;
    return style;
}

fn saturatingMul(lhs: u16, rhs: u16) u16 {
    const product = @as(u32, lhs) * @as(u32, rhs);
    return @intCast(@min(product, std.math.maxInt(u16)));
}

test "ColumnList initializes with borrowed columns rows and focus" {
    const columns = [_]ColumnList.Column{.{ .width = .flex }};
    const row = [_]ColumnList.Cell{.{ .text = "Alpha" }};
    const rows = [_]ColumnList.Row{&row};
    const list = ColumnList.init(.{ .columns = &columns, .rows = &rows });

    try std.testing.expectEqual(@as(usize, 1), list.columns.len);
    try std.testing.expectEqual(@as(usize, 1), list.rows.len);
    try std.testing.expectEqual(@as(usize, 0), list.focusedIndex());
}

test "ColumnList update and handleEvent follow List messages" {
    const columns = [_]ColumnList.Column{.{ .width = .flex }};
    const row_a = [_]ColumnList.Cell{.{ .text = "Alpha" }};
    const row_b = [_]ColumnList.Cell{.{ .text = "Beta" }};
    const rows = [_]ColumnList.Row{ &row_a, &row_b };
    var list = ColumnList.init(.{ .columns = &columns, .rows = &rows });

    list.update(.move_next);
    try std.testing.expectEqual(@as(usize, 1), list.focusedIndex());

    const msg = list.handleEvent(.{ .key_press = .{ .codepoint = chasen.Key.enter } }).?;
    try std.testing.expect(msg == .activate);
    try std.testing.expectEqual(@as(usize, 1), msg.activate);
}

test "ColumnList renders fixed and flex columns" {
    const columns = [_]ColumnList.Column{
        .{ .width = .flex },
        .{ .width = .{ .fixed = 5 }, .alignment = .right },
    };
    const row = [_]ColumnList.Cell{
        .{ .text = "Name" },
        .{ .text = "7.1" },
    };
    const rows = [_]ColumnList.Row{&row};
    const list = ColumnList.init(.{ .columns = &columns, .rows = &rows });

    var ts: chasen.testing.TestSurface = undefined;
    try ts.init(16, 1);
    defer ts.deinit();

    list.view(&ts.surface, .{ .show_cursor = false });

    try ts.expectCellText(2, 0, "N");
    try ts.expectCellText(13, 0, "7");
}

test "ColumnList visible range accounts for header height" {
    const columns = [_]ColumnList.Column{.{ .header = "Name", .width = .flex }};
    const rows = [_]ColumnList.Row{
        &[_]ColumnList.Cell{.{ .text = "Alpha" }},
        &[_]ColumnList.Cell{.{ .text = "Beta" }},
        &[_]ColumnList.Cell{.{ .text = "Gamma" }},
        &[_]ColumnList.Cell{.{ .text = "Delta" }},
    };
    var list = ColumnList.init(.{ .columns = &columns, .rows = &rows });
    list.update(.move_next);
    list.update(.move_next);
    list.update(.move_next);

    var ts: chasen.testing.TestSurface = undefined;
    try ts.init(14, 3);
    defer ts.deinit();

    list.view(&ts.surface, .{ .show_header = true, .show_cursor = false });

    try ts.expectCellText(2, 0, "N");
    try ts.expectCellText(2, 1, "G");
    try ts.expectCellText(0, 2, ">");
    try ts.expectCellText(2, 2, "D");
}

test "ColumnList merges row style with column and cell patches" {
    const accent = chasen.Color{ .index = 3 };
    const columns = [_]ColumnList.Column{
        .{ .width = .{ .fixed = 4 } },
        .{ .width = .{ .fixed = 4 }, .style = .{ .fg = accent } },
    };
    const row = [_]ColumnList.Cell{
        .{ .text = "A" },
        .{ .text = "B", .style = .{ .dim = true } },
    };
    const rows = [_]ColumnList.Row{&row};
    const list = ColumnList.init(.{ .columns = &columns, .rows = &rows });

    var ts: chasen.testing.TestSurface = undefined;
    try ts.init(14, 1);
    defer ts.deinit();

    list.view(&ts.surface, .{ .focused_style = .{ .bold = true }, .show_cursor = false });

    const cell = ts.surface.readCell(8, 0).?;
    try std.testing.expect(cell.style.bold);
    try std.testing.expect(cell.style.dim);
    try std.testing.expect(cell.style.fg.eql(accent));
}

test "ColumnList truncates cells without allocation" {
    const columns = [_]ColumnList.Column{.{ .width = .{ .fixed = 4 } }};
    const row = [_]ColumnList.Cell{.{ .text = "abcdef" }};
    const rows = [_]ColumnList.Row{&row};
    const list = ColumnList.init(.{ .columns = &columns, .rows = &rows });

    var ts: chasen.testing.TestSurface = undefined;
    try ts.init(8, 1);
    defer ts.deinit();

    list.view(&ts.surface, .{ .show_cursor = false });

    try ts.expectCellText(2, 0, "a");
    try ts.expectCellText(4, 0, "c");
    try ts.expectCellText(5, 0, "…");
}
